{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE NoApplicativeDo, RebindableSyntax #-}
{-# OPTIONS_GHC -Wno-unused-do-bind #-}
{-# LANGUAGE PolyKinds #-}
module FiftAsm.Dictionary
       ( Dict
       , DSet
       , Size
       , newDict
       , ldDict
       , stDict
       , dictGet
       , dictRemMin
       , dictIter
       , dictSet
       , dsetGet
       , dsetSet
       , dictDelIgnore
       , dictEmpty
       , dictSize
       , dictMerge

       , dictEncodeSet
       ) where
import Data.Vinyl.TypeLevel (type (++))
import Prelude
import FiftAsm.Instr
import FiftAsm.Types
import FiftAsm.DSL
import FiftAsm.Cell
data Dict k v
type DSet k = Dict k ()
type instance ToTVM (Dict k v) = 'DictT
newtype Size = Size Word32
    deriving (Eq, Ord, Show, Enum, Num, Real, Integral)
type instance ToTVM Size = 'IntT
instance DecodeSlice (Dict k v) where
    decodeFromSliceImpl = ldDict
    preloadFromSliceImpl = pldDict
instance EncodeBuilder (Dict k v) where
    encodeToBuilder = stDict
class DictOperations k v where
    dictGet :: Dict k v & k & s :-> Mb '[v] & s
    dictSet :: Dict k v & k & v & s :-> Dict k v & s
    dictDel :: Dict k v & k & s :-> Bool & Dict k v & s
class (ToTVM k ~ tvmk, ToTVM v ~ tvmv, IsUnsignedTF k ~ isUnsignedFlag)
      => DictOperations' tvmk tvmv isUnsignedFlag k v where
    dictGet' :: Dict k v & k & s :-> Mb '[v] & s
    dictSet' :: Dict k v & k & v & s :-> Dict k v & s
    dictDel' :: Dict k v & k & s :-> Bool & Dict k v & s
instance
  ( ToTVM k ~ 'SliceT
  , ToTVM v ~ 'SliceT
  , IsUnsignedTF k ~ 'False
  , KnownNat (BitSize k)
  )
  => DictOperations' 'SliceT 'SliceT 'False k v where
    dictGet' = do
        pushInt (bitSize @k)
        mkI DICTGET
    dictSet' = do
        pushInt (bitSize @k)
        mkI DICTSET
    dictDel' = do
        pushInt (bitSize @k)
        mkI DICTDEL
instance (ToTVM k ~ 'IntT, ToTVM v ~ 'SliceT, IsUnsignedTF k ~ 'True, KnownNat (BitSize k))
        => DictOperations' 'IntT 'SliceT 'True k v where
    dictGet' = do
        pushInt (bitSize @k)
        mkI DICTUGET
    dictSet' = do
        pushInt (bitSize @k)
        mkI DICTUSET
    dictDel' = do
        pushInt (bitSize @k)
        mkI DICTUDEL
instance ( ToTVM k ~ 'IntT, ToTVM v ~ 'DictT, IsUnsignedTF k ~ 'True, KnownNat (BitSize k),
           EncodeBuilder v, EncodeBuilderFields v ~ '[v],
           DecodeSlice v, DecodeSliceFields v ~ '[v],
           Typeable v
         )
        => DictOperations' 'IntT 'DictT 'True k v where
    dictGet' = do
        pushInt (bitSize @k)
        mkI DICTUGET
        fmapMaybe @'[Slice] @'[v] (decodeFromSlice @v >> drop)
    dictSet' :: forall s . Dict k v & k & v & s :-> Dict k v & s
    dictSet' = do
        roll @2
        encodeToSlice @v @(Dict k v & k & s)
        rollRev @2
        pushInt (bitSize @k)
        mkI DICTUSET
    dictDel' = do
        pushInt (bitSize @k)
        mkI DICTUDEL
instance ( ToTVM k ~ 'IntT, ToTVM v ~ 'IntT, IsUnsignedTF k ~ 'True, KnownNat (BitSize k),
           EncodeBuilder v, EncodeBuilderFields v ~ '[v],
           DecodeSlice v, DecodeSliceFields v ~ '[v],
           Typeable v
         )
        => DictOperations' 'IntT 'IntT 'True k v where
    dictGet' = do
        pushInt (bitSize @k)
        mkI DICTUGET
        fmapMaybe @'[Slice] @'[v] (decodeFromSlice @v >> drop)
    dictSet' :: forall s . Dict k v & k & v & s :-> Dict k v & s
    dictSet' = do
        roll @2
        encodeToSlice @v @(Dict k v & k & s)
        rollRev @2
        pushInt (bitSize @k)
        mkI DICTUSET
    dictDel' = do
        pushInt (bitSize @k)
        mkI DICTUDEL
instance DictOperations' (ToTVM k) (ToTVM v) (IsUnsignedTF k) k v => DictOperations k v where
    dictGet = dictGet'
    dictSet = dictSet'
    dictDel = dictDel'
dictEncodeSet
  :: forall k v s .
    ( EncodeBuilder v
    , ProhibitMaybeTF (ToTVM v)
    , ProhibitMaybeTF (ToTVM k)
    , DictOperations k v
    )
  => EncodeBuilderFields v ++ (k & Dict k v & s) :-> Dict k v & s
dictEncodeSet = do
    encodeToSlice @v @(k & Dict k v & s)
    cast @Slice @v
    reversePrefix @3
    dictSet @k @v
dsetGet :: forall k s . DictOperations k () => DSet k & k & s :-> Bool & s
dsetGet = do
    dictGet
    if IsJust then drop >> true
    else false
dsetSet :: forall k s . (DictOperations k (), ProhibitMaybe (ToTVM k)) => DSet k & k & s :-> DSet k & s
dsetSet = do
    unit
    rollRev @2
    dictSet
dictDelIgnore :: forall k v s . DictOperations k v => Dict k v & k & s :-> Dict k v & s
dictDelIgnore = do
    dictDel
    drop
newDict :: forall k v s . s :-> Dict k v & s
newDict = mkI NEWDICT
ldDict :: forall k v s . Slice & s :-> Slice & Dict k v & s
ldDict = mkI LDDICT
pldDict :: forall k v s . Slice & s :-> Dict k v & s
pldDict = mkI PLDDICT
stDict :: forall k v s . Builder & Dict k v & s :-> Builder & s
stDict = mkI STDICT
type DictRemMinC k v =
    ( DecodeSlice k, DecodeSlice v, KnownNat (BitSize k)
    , DecodeSliceFields k ~ '[k]
    , ProhibitMaybe (ToTVM k)
    , Typeable k
    , Typeable v
    , (DecodeSliceFields v ++ '[]) ~ DecodeSliceFields v
    , Typeable (DecodeSliceFields v)
    )
dictRemMin
    :: forall k v s . DictRemMinC k v
    => Dict k v & s :-> (Mb '[ k, Slice ] & Dict k v & s)
dictRemMin =
  viaSubroutine @'[Dict k v]
                @'[Mb '[ k, Slice ], Dict k v]
                "dictRemMin" $ do
    pushInt (bitSize @k)
    mkI DICTREMMIN
    fmapMaybe @'[Slice, Slice] @'[k, Slice] $ decodeFromSliceUnsafe @k
dictIter'
    :: forall k v s . DictRemMinC k v
    => k & Slice & Dict k v & s :-> Dict k v & s
    -> Dict k v & s :-> s
dictIter' onEntry = do
    comment "Iterate over dictionary"
    dictRemMin @k @v
    while (mkI MAYBE_TO_BOOL) $ do
        ifJust @'[k, Slice] onEntry ignore
        dictRemMin @k @v
    if IsJust then
        drop >> drop
    else
        ignore
    drop
dictIter
    :: forall k v s . DictRemMinC k v
    => DecodeSliceFields v ++ (k & Dict k v & s) :-> Dict k v & s
    -> Dict k v & s :-> s
dictIter onEntry = dictIter' $ do
    swap
    decodeFromSliceUnsafe @v
    onEntry
dictEmpty :: Dict k v & s :-> Bool & s
dictEmpty = mkI DICTEMPTY
dictSize
    :: forall k v s . DictRemMinC k v
    => Dict k v & Word32 & s :-> Mb '[Size] & s
dictSize = viaSubroutine @'[Dict k v, Word32] @'[Mb '[Size]] "dictSize" $ do
    pushInt @Size 0
    swap
    dictIter' $ do
        drop
        drop
        swap
        inc
        dup
        stacktype' @[Size, Size, Dict k v, Word32]
        push @3
        -- if `size >= k`, let's replace a dict with empt one to stop iteration
        if Proxy @Size >:= Proxy @Word32 then do
            swap
            drop
            newDict @k @v
        else swap
    stacktype @'[Size, Word32]
    dup
    rollRev @2
    stacktype' @[Size, Word32, Size]
    if Proxy @Word32 >: Proxy @Size
      then just
      else drop >> nothing
dictMerge
    :: forall k v s .
    ( DictRemMinC k v
    , DictOperations k v
    , DecodeSliceFields v ~ '[v]
    , ProhibitMaybe (ToTVM v)
    )
    => Dict k v & Dict k v & Word32 & s :-> Mb '[Dict k v] & s
dictMerge =
  viaSubroutine @'[Dict k v, Dict k v, Word32]
                @'[Mb '[Dict k v]]
                "dictMerge" $ do
    dup
    dictEmpty
    if Holds then do
        drop
        dup
        rollRev @2
        dictSize
        if IsJust then
            drop >> just @'[Dict k v]
        else
            drop >> nothing
    else do
        dup
        push @3
        swap
        dictSize
        stacktype' @[Mb '[Size], Dict k v, Dict k v, Word32]
        if IsNothing then
            drop >> drop >> drop >> nothing
        else do
            moveOnTop @2
            stacktype' @[Dict k v, Size, Dict k v, Word32]
            dictIter $ do
                swap
                dup
                push @3
                dictGet
                stacktype' @[Mb '[v], k, v, Dict k v, Size, Dict k v, Word32]
                if IsJust then
                    drop >> drop >> drop
                else do
                    moveOnTop @4
                    dictSet
                    roll @2
                    inc
                    dup
                    push @4
                    -- Check @size >= k@
                    if Proxy @Size >:= Proxy @Word32
                      then do
                        roll @2
                        drop
                        newDict @k @v
                      else roll @2
            stacktype' @[Size, Dict k v, Word32]
            moveOnTop @2
            if Proxy @Size >:= Proxy @Word32
              then drop >> nothing
              else just