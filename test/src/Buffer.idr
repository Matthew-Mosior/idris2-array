module Buffer

import Control.Monad.Identity
import Data.Buffer.Core
import Data.Buffer.Indexed
import Data.SOP
import Data.SnocList
import Data.Vect
import Hedgehog

%default total

bufferOf : (n : _) -> Gen Bits8 -> Gen (IBuffer n)
bufferOf n g = buffer <$> vect n g

buf : (n : Nat) -> Gen (IBuffer n)
buf n = bufferOf n anyBits8

prop_eq_refl : Property
prop_eq_refl = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (buf n)
  vs === vs

prop_eq_sym : Property
prop_eq_sym = property $ do
  n  <- forAll (nat $ linear 0 20)
  [vs,ws] <- forAll $ np [buf n,buf n]
  (vs == ws) === (ws == vs)

prop_eq_trans : Property
prop_eq_trans = property $ do
  n  <- forAll (nat $ linear 0 20)
  [us,vs,ws] <- forAll $ np [buf n,buf n,buf n]
  when (us == vs && vs == ws) (us === ws)

prop_eq_eq : Property
prop_eq_eq = property $ do
  n  <- forAll (nat $ linear 0 20)
  [vs,ws] <- forAll $ np [buf n,buf n]
  when (vs == ws) $ do
    assert (vs <= ws)
    assert (vs >= ws)
    assert (ws >= vs)
    assert (ws <= vs)
    (compare vs ws === EQ)

prop_eq_neq : Property
prop_eq_neq = property $ do
  n  <- forAll (nat $ linear 0 20)
  [vs,ws] <- forAll $ np [buf n,buf n]
  when (vs /= ws) $ do
    assert (vs < ws || ws < vs)

prop_lt : Property
prop_lt = property $ do
  n  <- forAll (nat $ linear 0 20)
  [vs,ws] <- forAll $ np [buf n,buf n]
  ((vs < ws) === (ws > vs))
  when (vs < ws) $ do
    assert (vs /= ws)
    assert (vs <= ws)
    assert (ws >= vs)

prop_lte : Property
prop_lte = property $ do
  n  <- forAll (nat $ linear 0 20)
  [vs,ws] <- forAll $ np [buf n,buf n]
  ((vs <= ws) === (ws >= vs))

prop_map_id : Property
prop_map_id = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (buf n)
  vs === map id vs

prop_from_to_list : Property
prop_from_to_list = property $ do
  vs <- forAll (list (linear 0 10) anyBits8)
  toList (bufferL vs) === vs

prop_from_to_vect : Property
prop_from_to_vect = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (vect n anyBits8)
  toVect (buffer vs) === vs

prop_from_to_rev_vect : Property
prop_from_to_rev_vect = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (vect n anyBits8)
  toVect (revArray vs) === reverse vs

prop_foldl : Property
prop_foldl = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (buf n)
  foldl (:<) [<] vs === foldl (:<) [<] (toList vs)

prop_foldr : Property
prop_foldr = property $ do
  n  <- forAll (nat $ linear 0 20)
  vs <- forAll (buf n)
  foldr (::) [] vs === foldr (::) [] (toList vs)

prop_generate : Property
prop_generate = property1 $
  toList (Indexed.generate 5 $ \x => let n := cast $ finToNat x in n*n) === [0,1,4,9,16]

prop_iterate : Property
prop_iterate = property1 $
  toList (Indexed.iterate 5 (*3) 1) === [1,3,9,27,81]

prop_foldrKV : Property
prop_foldrKV = property1 $
  foldrKV (\x,v,vs => (x,v) :: vs) [] (buffer [7,8,10]) ===
  (the (List (Fin 3, Bits8)) [(0,7), (1,8), (2,10)])

prop_foldlKV : Property
prop_foldlKV = property1 $
  foldlKV (\x,sv,v => sv :< (x,v)) [<] (buffer [7,8,10]) ===
  [<(0,7), (1,8), (2,10)]

prop_traverse_id : Property
prop_traverse_id = property $ do
  n <- forAll (nat $ linear 0 20)
  x <- forAll (buf n)
  traverse Id x === Id x

export
props : Group
props = MkGroup "Buffer"
  [ ("prop_eq_refl", prop_eq_refl)
  , ("prop_eq_sym", prop_eq_sym)
  , ("prop_eq_trans", prop_eq_trans)
  , ("prop_eq_eq", prop_eq_eq)
  , ("prop_eq_neq", prop_eq_neq)
  , ("prop_lt", prop_lt)
  , ("prop_lte", prop_lte)
  , ("prop_map_id", prop_map_id)
  , ("prop_from_to_list", prop_from_to_list)
  , ("prop_from_to_vect", prop_from_to_vect)
  , ("prop_from_to_rev_vect", prop_from_to_rev_vect)
  , ("prop_foldl", prop_foldl)
  , ("prop_foldr", prop_foldr)
  , ("prop_generate", prop_generate)
  , ("prop_iterate", prop_iterate)
  , ("prop_foldrKV", prop_foldrKV)
  , ("prop_foldlKV", prop_foldlKV)
  , ("prop_traverse_id", prop_traverse_id)
  ]

