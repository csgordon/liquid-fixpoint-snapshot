module Language.Fixpoint.Solver.Worklist
       ( -- * Worklist type is opaque
         Worklist

         -- * Initialize
       , init

         -- * Pop off a constraint
       , pop

         -- * Add a constraint and all its dependencies
       , push

       )
       where

import           Prelude hiding (init)
import           Language.Fixpoint.Misc
import           Language.Fixpoint.Config
import qualified Language.Fixpoint.Types   as F
import qualified Data.HashMap.Strict       as M
import qualified Data.HashSet              as S
import           Data.Maybe (fromMaybe)

---------------------------------------------------------------------------
-- | Worklist -------------------------------------------------------------
---------------------------------------------------------------------------

---------------------------------------------------------------------------
init :: Config -> F.FInfo a -> Worklist a
---------------------------------------------------------------------------
init _ fi = WL roots (cSucc cd) (F.cm fi)
  where
    cd    = cDeps fi
    roots = S.fromList $ cRoots cd

---------------------------------------------------------------------------
pop  :: Worklist a -> Maybe (F.SubC a, Worklist a)
---------------------------------------------------------------------------
pop w = do
  (i, is) <- sPop $ wCs w
  Just (getC w i, w {wCs = is})

getC :: Worklist a -> CId -> F.SubC a
getC w i = fromMaybe err $ M.lookup i $ wCm w
  where
    err  = errorstar "getC: bad CId i"

---------------------------------------------------------------------------
push :: F.SubC a -> Worklist a -> Worklist a
---------------------------------------------------------------------------
push c w = w {wCs = sAdds (wCs w) (i:js)}
  where
    i    = sid' c
    js   = wDeps w i

sid'    :: F.SubC a -> Integer
sid' c  = fromMaybe err $ F.sid c
  where
    err = errorstar "sid': SubC without id"


---------------------------------------------------------------------------
-- | Worklist -------------------------------------------------------------
---------------------------------------------------------------------------

type CId   = Integer

data Worklist a = WL { wCs   :: S.HashSet CId
                     , wDeps :: CId -> [CId]
                     , wCm   :: M.HashMap CId (F.SubC a)
                     }

---------------------------------------------------------------------------
-- | Constraint Dependencies ----------------------------------------------
---------------------------------------------------------------------------

data CDeps = CDs { cRoots :: ![CId]
                 , cSucc  :: CId -> [CId]
                 }

cDeps :: F.FInfo a -> CDeps
cDeps = error "TODO"

---------------------------------------------------------------------------
-- | Set API --------------------------------------------------------------
---------------------------------------------------------------------------

sAdds :: S.HashSet a -> [a] -> S.HashSet a
sAdds = error "TODO"

sPop :: S.HashSet a -> Maybe (a, S.HashSet a)
sPop = error "TODO"

