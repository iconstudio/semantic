{-# LANGUAGE LambdaCase #-}
module Data.Patch
( Patch(..)
, after
, before
, patch
) where

import Prologue
import Data.Aeson
import Data.Align
import Data.JSON.Fields

-- | An operation to compare, insert, or delete an item.
data Patch a b
  = Delete a
  | Insert b
  | Compare a b
  deriving (Eq, Foldable, Functor, Generic, Generic1, Ord, Show, Traversable)


-- | Return the item from the after side of the patch.
after :: Patch before after -> Maybe after
after = patch (const Nothing) Just (\ _ b -> Just b)

-- | Return the item from the before side of the patch.
before :: Patch before after -> Maybe before
before = patch Just (const Nothing) (\ a _ -> Just a)

-- | Return both sides of a patch.
patch :: (before -> result) -> (after -> result) -> (before -> after -> result) -> Patch before after -> result
patch ifDelete _ _ (Delete a) = ifDelete a
patch _ ifInsert _ (Insert b) = ifInsert b
patch _ _ ifReplace (Compare a b) = ifReplace a b


instance Bifunctor Patch where
  bimap f g = \case
    Delete  a   -> Delete (f a)
    Insert    b -> Insert (g b)
    Compare a b -> Compare (f a) (g b)

instance Bifoldable Patch where
  bifoldMap f g = \case
    Delete  a   -> f a
    Insert    b -> g b
    Compare a b -> f a <> g b

instance Bitraversable Patch where
  bitraverse f g = \case
    Delete  a   -> Delete <$> f a
    Insert    b -> Insert <$> g b
    Compare a b -> Compare <$> f a <*> g b

instance Bicrosswalk Patch where
  bicrosswalk f g = \case
    Delete  a   -> Delete <$> f a
    Insert    b -> Insert <$> g b
    Compare a b -> alignWith (these Delete Insert Compare) (f a) (g b)

instance Eq2 Patch where
  liftEq2 eqBefore eqAfter p1 p2 = case (p1, p2) of
    (Delete a1, Delete a2) -> eqBefore a1 a2
    (Insert b1, Insert b2) -> eqAfter b1 b2
    (Compare a1 b1, Compare a2 b2) -> eqBefore a1 a2 && eqAfter b1 b2
    _ -> False

instance Show2 Patch where
  liftShowsPrec2 spBefore _ spAfter _ d = \case
    Delete a -> showsUnaryWith spBefore "Delete" d a
    Insert b -> showsUnaryWith spAfter "Insert" d b
    Compare a b -> showsBinaryWith spBefore spAfter "Compare" d a b


instance (ToJSONFields a, ToJSONFields b) => ToJSONFields (Patch a b) where
  toJSONFields (Insert a)    = [ "insert" .= object (toJSONFields a) ]
  toJSONFields (Delete a)    = [ "delete" .= object (toJSONFields a) ]
  toJSONFields (Compare a b) = [ "replace" .= [object (toJSONFields a), object (toJSONFields b)] ]
