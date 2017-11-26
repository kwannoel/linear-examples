-- |
-- A variant of the State monad in which every bound variable
-- must be used (or returned) exactly once. So this compiles:
--
-- >>> :set -XRebindableSyntax
-- >>> import PreludeL.RebindableSyntax
-- >>> :{
-- let linear :: StateL s s
--     linear = do
--       returned <- getL
--       pureL returned
-- :}
--
-- But this does not:
--
-- >>> :{
-- let notLinear :: StateL s s
--     notLinear = do
--       _notConsumed <- getL
--       returned <- getL
--       pureL returned
-- :}
-- ...
-- ...Couldn't match expected weight ‘1’ of variable ‘_notConsumed’ with actual weight ‘0’
-- ...
{-# LANGUAGE InstanceSigs, ScopedTypeVariables #-}
module StateL where

import Prelude hiding ((>>=))
import PreludeL


data StateL s a = StateL
  { unStateL :: Unrestricted s ->. (Unrestricted s, a) }

instance FunctorL (StateL s) where
  fmapL f (StateL body) = StateL $ \s
                       -> body s &. \(s', x)
                       -> (s', f x)

instance ApplicativeL (StateL s) where
  pureL x = StateL $ \s -> (s, x)
  StateL bodyF <*>. StateL bodyX = StateL $ \s
                                -> bodyF s  &. \(s', f)
                                -> bodyX s' &. \(s'', x)
                                -> (s'', f x)


instance MonadL (StateL s) where
  StateL bodyX >>=. cc = StateL $ \s
                      -> bodyX s  &. \(s', x)
                      -> cc x &. \(StateL bodyY)
                      -> bodyY s'

getL :: StateL s s
getL = StateL $ \(Unrestricted s)
    -> (Unrestricted s, s)

modifyL :: (s -> s) -> StateL s ()
modifyL body = StateL $ \(Unrestricted s)
            -> (Unrestricted (body s), ())

execStateL :: StateL s () ->. s -> s
execStateL (StateL body) s = body (Unrestricted s) &. \(Unrestricted s', ())
                          -> s'
