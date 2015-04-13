{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE TupleSections #-}

-- | Solve a system of horn-clause constraints ----------------------------

module Language.Fixpoint.Solver.Solve (solve) where

import           Control.Monad (filterM)
import           Control.Applicative ((<$>))
import qualified Data.HashMap.Strict  as M
import qualified Language.Fixpoint.Types as F
import           Language.Fixpoint.Config
import qualified Language.Fixpoint.Solver.Solution as S
import qualified Language.Fixpoint.Solver.Worklist as W
import           Language.Fixpoint.Solver.Monad
import qualified Data.List as L

---------------------------------------------------------------------------
-- | The output of the Solver
---------------------------------------------------------------------------
type Result a = (F.FixResult (F.SubC a), M.HashMap F.KVar F.Pred)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
solve :: Config -> F.FInfo a -> IO (Result a)
---------------------------------------------------------------------------
solve cfg fi = runSolverM cfg be $ solve_ cfg fi'
  where
    fi'      = rename fi
    be       = F.bs fi'

---------------------------------------------------------------------------
solve_ :: Config -> F.FInfo a -> SolveM (Result a)
---------------------------------------------------------------------------
solve_ cfg fi = refine s0 wkl >>= result fi
  where
    s0        = S.init cfg fi
    wkl       = W.init cfg fi

---------------------------------------------------------------------------
refine :: S.Solution -> W.Worklist a -> SolveM S.Solution
---------------------------------------------------------------------------
refine s w
  | Just (c, w') <- W.pop w = do (b, s') <- refineC s c
                                 if b then refine s' (W.push c w')
                                      else return s'
  | otherwise               = return s

---------------------------------------------------------------------------
-- | Single Step Refinement -----------------------------------------------
---------------------------------------------------------------------------
refineC :: S.Solution -> F.SubC a -> SolveM (Bool, S.Solution)
---------------------------------------------------------------------------
refineC s c
  | null rhs  = return (False, s)
  | otherwise = do lhs        <-  lhsPred  s c <$> getBinds
                   S.update s <$> filterValid lhs rhs
  where
    rhs       =  rhsCands s c

lhsPred :: S.Solution -> F.SubC a -> F.BindEnv -> F.Pred
lhsPred s c be = F.pAnd $ pGrd : pLhs : pBinds
  where
    pGrd       = F.sgrd c
    pLhs       = S.apply s  $  F.lhsCs c
    pBinds     = S.apply s <$> xts
    xts        = F.envCs be $  F.senv c

rhsCands :: S.Solution -> F.SubC a -> S.Cand (F.KVar, S.EQual)
rhsCands s c   = [ cnd k su q | (k, su) <- ks c, q <- S.lookup s k]
  where
    ks         = predKs . F.reftPred . F.rhsCs
    cnd k su q = (F.subst su (S.eqPred q), (k, q))

predKs :: F.Pred -> [(F.KVar, F.Subst)]
predKs (F.PAnd ps)    = concatMap predKs ps
predKs (F.PKVar k su) = [(k, su)]
predKs _              = []

---------------------------------------------------------------------------
-- | Convert Solution into Result -----------------------------------------
---------------------------------------------------------------------------
result :: F.FInfo a -> S.Solution -> SolveM (Result a)
---------------------------------------------------------------------------
result fi s = (, sol) <$> result_ fi s
  where
    sol     = M.map (F.pAnd . fmap S.eqPred) s

result_ :: F.FInfo a -> S.Solution -> SolveM (F.FixResult (F.SubC a))
result_ fi s = res <$> filterM (isUnsat s) cs
  where
    cs       = M.elems $ F.cm fi
    res []   = F.Safe
    res cs'  = F.Unsafe cs'

---------------------------------------------------------------------------
isUnsat :: S.Solution -> F.SubC a -> SolveM Bool
---------------------------------------------------------------------------
isUnsat s c = do
  lp    <- lhsPred s c <$> getBinds
  let rp = rhsPred s c
  not   <$> isValid lp rp

isValid :: F.Pred -> F.Pred -> SolveM Bool
isValid p q = (not . null) <$> filterValid p [(q, ())]

rhsPred :: S.Solution -> F.SubC a -> F.Pred
rhsPred s c = S.apply s $ F.rhsCs c


---------------------------------------------------------------------------
-- | Alpha Rename bindings to ensure each var appears in unique binder
---------------------------------------------------------------------------
rename :: F.FInfo a -> F.FInfo a
---------------------------------------------------------------------------

-- TODO: Fix `rename` to enforce uniqueness, AND add bindings for VVs
rename fi = fi {F.bs = be'} -- error "TODO"
  where
    vts   = map subcVV $ M.elems $ F.cm fi
    be'   = L.foldl' addVV be vts
    be    = F.bs fi

addVV :: F.BindEnv -> (F.Symbol, F.SortedReft) -> F.BindEnv
addVV b (x, t) = snd $ F.insertBindEnv x t b

subcVV :: F.SubC a -> (F.Symbol, F.SortedReft)
subcVV c = (x, sr)
  where
    sr   = F.slhs c
    x    = F.reftBind $ F.sr_reft sr
