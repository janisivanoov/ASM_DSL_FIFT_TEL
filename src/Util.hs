{-# LANGUAGE PolyKinds #-}
module Util
       ( Take
       , Drop
       , Head
       , Tail
       , Swap
       , Reverse
       , RecAll_

       -- Reexports
       , Nat
       , type (-)
       , type (++)
       ) where
import GHC.TypeLits (Nat, TypeError, ErrorMessage (..), type (-))
import Data.Vinyl.TypeLevel (type (++))
type family Take (n :: Nat) (xs :: [k]) where
    Take 0 _ = '[]
    Take _ '[] =
        TypeError ('Text "Take: type level list doesn't have needed amount of elements")
    Take n (x ': xs) = x ': Take (n - 1) xs
type family Drop (n :: Nat) (xs :: [k]) where
    Drop 0 xs = xs
    Drop _ '[] =
        TypeError ('Text "Drop: type level list doesn't have needed amount of elements")
    Drop n (x ': xs) = Drop (n - 1) xs
type family Tail (xs :: [k]) where
    Tail (_ ': xs) = xs
    Tail _ = TypeError ('Text "Tail doesn't exist")
type family Head (xs :: [k]) where
    Head (x ': _) = x
    Head _ = TypeError ('Text "Head doesn't exist")
type family Swap (xs :: [k]) where
    Swap (x ': y ': s) = y ': x ': s
    Swap _ = TypeError ('Text "Swap: at least two elements don't exist")
type family Reverse (xs :: [k]) where
    Reverse '[] = '[]
    Reverse (x ': xs) = Reverse xs ++ '[x]
type family RecAll_ (rs :: [u]) (c :: u -> Constraint) :: Constraint where
    RecAll_ '[] c = ()
    RecAll_ (r ': rs) c = (c r, RecAll_ rs c)
