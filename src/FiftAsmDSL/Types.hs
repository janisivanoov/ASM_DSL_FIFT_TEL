module FiftAsm.Types
       ( T (..)
       ) where
data T
    = IntT
    | CellT
    | TupleT [T]
    | SliceT
    | BuilderT
    | NullT
    | MaybeT [T]
    | DictT