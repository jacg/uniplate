-- This module requires tricky CPP'ing
-- so that you can use 3 different Play instances

module Operations(tasksExpr,tasksStm) where

import Data
import DeriveCompos
import OperationsCommon
import DeriveManual

import Data.Generics.PlayEx as Play
import Data.Generics as SYB


tasksExpr = variables ++ zeros
tasksStm = rename ++ symbols


-- * SECTION 1


variables = task "variables" [variables_raw, variables_play, variables_play2, variables_syb, variables_comp]

variables_raw = rawExpr id f
    where
        f (NVar  x    ) = [x]
        f (NVal  x    ) = []
        f (NNeg  x    ) = f x
        f (NAdd  x y  ) = f x ++ f y
        f (NSub  x y  ) = f x ++ f y
        f (NMul  x y  ) = f x ++ f y
        f (NDiv  x y  ) = f x ++ f y


variables_play = playExpr id $ \x -> [y | NVar y <- Play.everything x]

variables_play2 = alt "fold" $ playExpr id $ fold concat f
    where
        f (NVar x) c = x : c
        f _ c = c

variables_syb = sybExpr id $ SYB.everything (++) ([] `mkQ` f)
    where
        f (NVar x) = [x]
        f _ = []

variables_comp = compExpr id f
    where
        f :: GExpr a -> [String]
        f (CVar x) = [x]
        f x = composOpFold [] (++) f x



zeros = task "zeros" [zeros_raw, zeros_play, zeros_play2, zeros_syb, zeros_comp]

zeros_raw = rawExpr id f
    where
        f (NDiv  x (NVal 0)) = f x + 1
        f (NVar  x    ) = 0
        f (NVal  x    ) = 0
        f (NNeg  x    ) = f x
        f (NAdd  x y  ) = f x + f y
        f (NSub  x y  ) = f x + f y
        f (NMul  x y  ) = f x + f y
        f (NDiv  x y  ) = f x + f y

zeros_play = playExpr id $ \x -> length [() | NDiv _ (NVal 0) <- Play.everything x]

zeros_play2 = alt "fold" $ playExpr id $ fold sum f
    where
        f (NDiv _ (NVal 0)) c = 1 + c
        f _ c = c

zeros_syb = sybExpr id $ SYB.everything (+) (0 `mkQ` f)
    where
        f (NDiv _ (NVal 0)) = 1
        f _ = 0

zeros_comp = compExpr id f
    where
        f :: GExpr a -> Int
        f (CDiv x (CVal 0)) = 1 + f x 
        f x = composOpFold 0 (+) f x



simplify = task "simplify" [simplify_raw,simplify_play,simplify_play2,simplify_syb,simplify_compos]

simplify_raw = rawExpr2 f
    where
        f (NSub x y) = NAdd (f x) (NNeg (f y))
        f (NAdd x y) = if x1 == y1 then NMul (NVal 2) x1 else NAdd x1 y1
            where (x1,y1) = (f x,f y)
        f (NMul x y) = NMul (f x) (f y)
        f (NDiv x y) = NDiv (f x) (f y)
        f (NNeg x) = NNeg (f x)
        f x = x

simp (NSub x y)           = NAdd x (NNeg y)
simp (NAdd x y) | x == y  = NMul (NVal 2) x
simp x                    = x

simplify_play = playExpr2 $ traverse simp

simplify_play2 = alt "rewrite" $ playExpr2 $ rewrite f
    where
        f (NSub x y)           = Just $ NAdd x (NNeg y)
        f (NAdd x y) | x == y  = Just $ NMul (NVal 2) x
        f x                    = Nothing

simplify_syb = sybExpr2 $ everywhere (mkT simp)

simplify_compos = compExpr2 f
    where
        f :: GExpr a -> GExpr a
        f (CSub x y) = CAdd (f x) (CNeg (f y))
        f (CAdd x y) = if x1 == y1 then CMul (CVal 2) x1 else CAdd x1 y1
            where (x1,y1) = (f x,f y)
        f x = composOp f x



rename = task "rename" [rename_compos, rename_play, rename_syb, rename_raw]

rename_compos = compStm2 f
    where
        f :: CTree c -> CTree c
        f t = case t of
            CV x -> CV ("_" ++ x)
            _ -> composOp f t
            
rename_op (NV x) = NV ("_" ++ x)

rename_play = playStm2 $ traverseEx rename_op

rename_syb = sybStm2 $ everywhere (mkT rename_op)

rename_raw = rawStm2 f
    where
        f (NSDecl a b) = NSDecl a (rename_op b)
        f (NSAss a b) = NSAss (rename_op a) (g b)
        f (NSBlock a) = NSBlock (map f a)
        f (NSReturn a) = NSReturn (g a)
        
        g (NEStm a) = NEStm (f a)
        g (NEAdd a b) = NEAdd (g a) (g b)
        g (NEVar a) = NEVar (rename_op a)
        g x = x



symbols = task "symbols" [symbols_compos,symbols_play,symbols_syb,symbols_raw]

rewrapPairC xs = [(rewrapVarC a, rewrapTypC b) | (a,b) <- xs]
rewrapPairN xs = [(rewrapVarN a, rewrapTypN b) | (a,b) <- xs]

symbols_compos = compStm rewrapPairC f
    where
        f :: CTree c -> [(CTree CVar, CTree CTyp)]
        f t = case t of
            CSDecl typ var -> [(var,typ)]
            _ -> composOpMonoid f t

symbols_play = playStm rewrapPairN $ \x -> [(v,t) | NSDecl t v <- everythingEx x]

symbols_syb = sybStm rewrapPairN $ SYB.everything (++) ([] `mkQ` f)
    where
        f (NSDecl t v) = [(v,t)]
        f _ = []

symbols_raw = rawStm rewrapPairN f
    where
        f (NSDecl a b) = [(b,a)]
        f (NSAss a b) = g b
        f (NSBlock a) = concatMap f a
        f (NSReturn a) = g a
        
        g (NEStm a) = f a
        g (NEAdd a b) = g a ++ g b
        g x = []