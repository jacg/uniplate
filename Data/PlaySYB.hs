{-# OPTIONS_GHC -fglasgow-exts -fallow-undecidable-instances #-}

module Data.PlaySYB(module Data.PlayEx, module Data.PlaySYB) where

import Data.PlayEx
import Data.Generics
import Data.Maybe
import Control.Monad.State


instance (Data a, Typeable a) => Play a where
    replaceChildren = collect_generate
    
    getChildren = concat . gmapQ getChildrenEx
    


instance (Data a, Play b, Typeable a, Typeable b) => PlayEx a b where
    replaceChildrenEx x = res
        where
            res = case asTypeOf (cast x) (Just $ head $ fst res) of
                       Just y -> ([y], \[x] -> fromJust (cast x))
                       Nothing -> collect_generate x

    getChildrenEx x = res
        where
            res = case asTypeOf (cast x) (Just $ head res) of
                       Just y -> [y]
                       Nothing -> concat $ gmapQ getChildrenEx x


collect_generate :: (Data on, Play with, Typeable on, Typeable with) => on -> ([with],[with] -> on)
collect_generate item = (collect, generate)
    where
        collect = execState (gmapM f item) []
            where
                f x = modify (++ extra) >> return x
                    where extra = fst $ replaceChildrenEx x

        generate xs = evalState (gmapM f item) xs
            where
                f x = do
                        ys <- get
                        let (as,bs) = splitAt (length col) ys
                        put bs
                        return $ gen as
                    where
                        (col,gen) = replaceChildrenEx x

