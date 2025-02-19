module Concurrent

import Data.Vect as V
import Data.Array
import Data.Array.Mutable
import System.Concurrency
import System

%default total

public export
ITER : Nat
ITER = 1_000_000

data Prog = Unsafe | CAS | Mut

inc : (r : MArray s 1 Nat) -> F1' s
inc r = modify r 0 S

casinc : (r : MArray s 1 Nat) -> F1' s
casinc r = casmodify r 0 S

mutinc : Mutex -> IOArray 1 Nat -> Nat -> IO ()
mutinc m r 0     = pure ()
mutinc m r (S k) = do
  mutexAcquire m
  runIO (inc r)
  mutexRelease m
  mutinc m r k

prog : Prog -> Mutex -> IOArray 1 Nat -> IO ()
prog Unsafe m ref = runIO (forN ITER $ inc ref)
prog CAS    m ref = runIO (forN ITER $ casinc ref)
prog Mut    m ref = mutinc m ref ITER

runProg : Prog -> Nat -> IO Nat
runProg prg n = do
  mut <- makeMutex
  ref <- marray 1 Z
  ts  <- sequence $ V.replicate n (fork $ prog prg mut ref)
  traverse_ (\t => threadWait t) ts
  runIO (get ref 0)

main : IO ()
main = do
  u <- runProg Unsafe 4
  c <- runProg CAS 4
  when (u >= c) (die "no race condition")
  when (c /= 4 * ITER) (die "CAS synchronization failed")
  putStrLn "Concurrent counter succeeded!"
