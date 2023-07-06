module Data.Array.Indexed

import public Data.Array.Mutable
import Data.List
import Data.Vect

%default total

||| An immutable array paired with its size (= number of values).
public export
record Array a where
  constructor A
  size : Nat
  arr  : IArray size a

--------------------------------------------------------------------------------
--          Accessing Data
--------------------------------------------------------------------------------

export %inline
ix : IArray n a -> (0 m : Nat) -> {auto x: Ix (S m) n} -> a
ix arr _ = at arr (ixToFin x)

export %inline
atNat : IArray n a -> (m : Nat) -> {auto 0 lt : LT m n} -> a
atNat arr x = at arr (natToFinLT x)

--------------------------------------------------------------------------------
--          Initializing Arrays
--------------------------------------------------------------------------------

export
empty : IArray 0 a
empty = believe_me $ unrestricted $ alloc 0 () freeze

export
arrayL : (ls : List a) -> IArray (length ls) a
arrayL []        = empty
arrayL (x :: xs) = unrestricted $ allocList (x::xs) freeze

export
array : {n : _} -> Vect n a -> IArray n a
array []        = empty
array (x :: xs) = unrestricted $ allocVect (x::xs) freeze

export
revArray : {n : _} -> Vect n a -> IArray n a
revArray []        = empty
revArray (x :: xs) = unrestricted $ allocRevVect (x::xs) freeze

export
generate : (n : Nat) -> (Fin n -> a) -> IArray n a
generate 0     f = empty
generate (S k) f = unrestricted $ allocGen (S k) f freeze

export
iterate : (n : Nat) -> (a -> a) -> a -> IArray n a
iterate 0     _ _ = empty
iterate (S k) f v = unrestricted $ allocIter (S k) f v freeze

export
force : {n : _} -> IArray n a -> IArray n a
force arr = generate n (at arr)

--------------------------------------------------------------------------------
--          Eq and Ord
--------------------------------------------------------------------------------

||| Lexicographic comparison of Arrays of distinct length
export
hcomp : {m,n : Nat} -> Ord a => IArray m a -> IArray n a -> Ordering
hcomp a1 a2 = go m n
  where
    go : (k,l : Nat) -> {auto _ : Ix k m} -> {auto _ : Ix l n} -> Ordering
    go 0     0     = EQ
    go 0     (S _) = LT
    go (S _) 0     = GT
    go (S k) (S j) = case compare (ix a1 k) (ix a2 j) of
      EQ => go k j
      r  => r

||| Heterogeneous equality for Arrays
export
heq : {m,n : Nat} -> Eq a => IArray m a -> IArray n a -> Bool
heq a1 a2 = go m n
  where
    go : (k,l : Nat) -> {auto _ : Ix k m} -> {auto _ : Ix l n} -> Bool
    go 0     0     = True
    go (S k) (S j) = if ix a1 k == ix a2 j then go k j else False
    go _     _     = False

export
{n : Nat} -> Eq a => Eq (IArray n a) where
  a1 == a2 = go n
    where
      go : (k : Nat) -> {auto 0 _ : LTE k n} -> Bool
      go 0     = True
      go (S k) = if atNat a1 k == atNat a2 k then go k else False

export
{n : Nat} -> Ord a => Ord (IArray n a) where
  compare a1 a2 = go n
    where
      go : (k : Nat) -> {auto _ : Ix k n} -> Ordering
      go 0     = EQ
      go (S k) = case compare (ix a1 k) (ix a2 k) of
        EQ => go k
        c  => c

--------------------------------------------------------------------------------
--          Maps and Folds
--------------------------------------------------------------------------------

ontoList : List a -> (m : Nat) -> {auto 0 lte : LTE m n} -> IArray n a -> List a
ontoList xs 0     arr = xs
ontoList xs (S k) arr = ontoList (atNat arr k :: xs) k arr

ontoVect :
     Vect k a
  -> (m : Nat)
  -> {auto 0 lte : LTE m n}
  -> IArray n a
  -> Vect (k + m) a
ontoVect xs 0     arr = rewrite plusZeroRightNeutral k in xs
ontoVect xs (S v) arr =
  rewrite sym (plusSuccRightSucc k v) in ontoVect (atNat arr v :: xs) v arr

ontoVectWithIndex :
     Vect k (Fin n, a)
  -> (m : Nat)
  -> {auto 0 lte : LTE m n}
  -> IArray n a
  -> Vect (k + m) (Fin n, a)
ontoVectWithIndex xs 0     arr = rewrite plusZeroRightNeutral k in xs
ontoVectWithIndex xs (S v) arr =
  rewrite sym (plusSuccRightSucc k v)
  in let x := natToFinLT v in ontoVectWithIndex ((x, at arr x) :: xs) v arr

export %inline
toVect : {n : _} -> IArray n a -> Vect n a
toVect = ontoVect [] n

export %inline
toVectWithIndex : {n : _} -> IArray n a -> Vect n (Fin n, a)
toVectWithIndex = ontoVectWithIndex [] n

foldrI : (m : Nat) -> (0 _ : LTE m n) => (e -> a -> a) -> a -> IArray n e -> a
foldrI 0     _ x arr = x
foldrI (S k) f x arr = foldrI k f (f (atNat arr k) x) arr

foldrKV_ :
     (m : Nat)
  -> {auto 0 prf : LTE m n}
  -> (Fin n -> e -> a -> a)
  -> a
  -> IArray n e -> a
foldrKV_ 0     _ x arr = x
foldrKV_ (S k) f x arr =
  let fin := natToFinLT k @{prf} in foldrKV_ k f (f fin (at arr fin) x) arr

foldlI : (m : Nat) -> (x : Ix m n) => (a -> e -> a) -> a -> IArray n e -> a
foldlI 0     _ v arr = v
foldlI (S k) f v arr = foldlI k f (f v (ix arr k)) arr

foldlKV_ :
     (m : Nat)
  -> {auto x : Ix m n}
  -> (Fin n -> a -> e -> a)
  -> a
  -> IArray n e
  -> a
foldlKV_ 0     _ v arr = v
foldlKV_ (S k) f v arr =
  let fin := ixToFin x in foldlKV_ k f (f fin v (at arr fin)) arr

export %inline
foldrKV : {n : _} -> (Fin n -> e -> a -> a) -> a -> IArray n e -> a
foldrKV = foldrKV_ n

export %inline
foldlKV : {n : _} -> (Fin n -> a -> e -> a) -> a -> IArray n e -> a
foldlKV = foldlKV_ n

export %inline
{n : Nat} -> Foldable (IArray n) where
  foldr = foldrI n
  foldl = foldlI n
  toList = ontoList [] n
  null _ = n == Z

export %inline
{n : Nat} -> Functor (IArray n) where
  map f arr = generate n (f . at arr)

export
{n : Nat} -> Show a => Show (IArray n a) where
  showPrec p arr = showCon p "array" (showArg $ ontoList [] n arr)

export
mapWithIndex : {n : _} -> (Fin n -> a -> b) -> IArray n a -> IArray n b
mapWithIndex f arr = generate n (\x => f x (at arr x))

export
updateAt : {n : _} -> Fin n -> (a -> a) -> IArray n a -> IArray n a
updateAt x f = mapWithIndex (\k,v => if heqFin x k then f v else v)

export
setAt : {n : _} -> Fin n -> a -> IArray n a -> IArray n a
setAt x y = mapWithIndex (\k,v => if heqFin x k then y else v)

--------------------------------------------------------------------------------
--          Traversals
--------------------------------------------------------------------------------

export
traverseWithIndex :
     {n : _}
  -> {auto app : Applicative f}
  -> (Fin n -> a -> f b)
  -> IArray n a
  -> f (IArray n b)
traverseWithIndex f arr =
  array <$> traverse (\(x,v) => f x v) (toVectWithIndex arr)

export
{n : _} -> Traversable (IArray n) where
  traverse = traverseWithIndex . const

--------------------------------------------------------------------------------
--          Subarrays
--------------------------------------------------------------------------------

0 curLTE : (s : Ix m n) -> LTE c (ixToNat s) -> LTE c n
curLTE s lte = transitive lte $ ixLTE s

0 curLT : (s : Ix (S m) n) -> LTE c (ixToNat s) -> LT c n
curLT s lte = let LTESucc p := ixLT s in LTESucc $ transitive lte p

export
filterWithKey :
     {n : Nat}
  -> (Fin n -> a -> Bool)
  -> IArray n a
  -> Array a
filterWithKey f arr = unrestricted $ unsafeAlloc n (go 0 n)
  where
    go :
         (cur,x : Nat)
      -> {auto s : Ix x n}
      -> {auto 0 lte : LTE cur $ ixToNat s}
      -> MArray n a
      -@ !* Array a
    go cur 0     marr =
      let MkBang res := freezeLTE cur @{curLTE s lte} marr
       in MkBang (A cur res)
    go cur (S j) marr = case f (ixToFin s) (ix arr j) of
      True  =>
        let marr2 := setNat cur @{curLT s lte} (ix arr j) marr
         in go (S cur) j marr2
      False => go cur j marr

export %inline
filter : {n : Nat} -> (a -> Bool) -> IArray n a -> Array a
filter = filterWithKey . const

export
mapMaybeWithKey :
     {n : Nat}
  -> (Fin n -> a -> Maybe b)
  -> IArray n a
  -> Array b
mapMaybeWithKey f arr = unrestricted $ unsafeAlloc n (go 0 n)
  where
    go :
         (cur,x : Nat)
      -> {auto s : Ix x n}
      -> {auto 0 lte : LTE cur $ ixToNat s}
      -> MArray n b
      -@ !* Array b
    go cur 0     marr =
      let MkBang res := freezeLTE cur @{curLTE s lte} marr
       in MkBang (A cur res)
    go cur (S j) marr = case f (ixToFin s) (ix arr j) of
      Just vb =>
        let marr2 := setNat cur @{curLT s lte} vb marr
         in go (S cur) j marr2
      Nothing => go cur j marr

export %inline
mapMaybe : {n : Nat} -> (a -> Maybe b) -> IArray n a -> Array b
mapMaybe = mapMaybeWithKey . const

export
append : {m,n : Nat} -> IArray m a -> IArray n a -> IArray (m + n) a
append {m = 0}   a1 a2 = a2
append {m = S v} a1 a2 = generate (S v + n) $ \x => case tryFinToFin {k = S v} x of
  Just y  => at a1 y
  Nothing => case tryNatToFin {k = n} (finToNat x `minus` S v) of
    Just y  => at a2 y
    Nothing => at a1 0
