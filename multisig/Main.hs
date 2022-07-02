module Main where
import Fmt
import MultiSig
import FiftAsm
main :: IO ()
main = putText $ pretty $ declProgram procedures methods
  where
    procedures =
      [ ("recv_external", decl recvExternal)
      , ("recv_internal", decl recvInternal)
      ]
    methods =
      [ ("allOrders", declMethod getAllOrders)
      , ("ordersByKey", declMethod getOrdersByKey)
      , ("seqno", declMethod getSeqno)
      ]
