module Moves (limitByRange, Range) where

import Game

import Hagl (forPlayer, PlayerID)
import Euterpea (Pitch, trans)

{-

This module contains code for generating sets of possible moves (i.e. 
improvised deviations) from a prescribed musical event given by the score.

Deviation from a given pitch is limited to within an integer range of pitches 
above and below it. A larger range increases the freedom for a player to 
improvise, but also increases the size of the game tree.  

-}

type Range = Int

-- | Generate a list of possible moves from a given range and score. We  
-- enforce the following invariants for possible moves:
--      - An Extend must follow a previous Begin or Extend, never a Rest
--      - An Extend must have the same pitch of the most recent Begin
availableMoves :: Range -> Performer -> [MusicMv]
availableMoves i performer = case performer of
  (Performer _               [])          -> []
  (Performer m@(Begin r:rs) (Begin f:fs)) -> Rest: Extend r: 
                                               fromPast i m ++ generateMoves i f
  (Performer m              (Begin f:fs)) -> Rest: fromPast i m 
                                               ++ generateMoves i f
  (Performer m@(Begin r:rs)  _ )          -> Rest: Extend r: fromPast i m
  (Performer m@(Extend r:rs) _ )          -> Rest: Extend r: fromPast i m
  (Performer m               _ )          -> Rest:           fromPast i m

-- | Produce a list of moves from the most recent past Begin.
fromPast :: Range -> [MusicMv] -> [MusicMv]
fromPast r (Begin p:prev) = generateMoves r p
fromPast r (_      :prev) = fromPast r prev
fromPast _ _              = []

-- | For a given range and pitch, generate a list of moves (Begins) range 
-- number of half steps above and below that pitch.
generateMoves :: Range -> Pitch -> [MusicMv]
generateMoves range p =
    let genMoves _ _ 0 = []
        genMoves p f n = let m = f p
                         in Begin m: genMoves m f (n-1)
    in Begin p: genMoves p (trans 1) range ++ genMoves p (trans (-1)) range

-- | Return a list of a player's available moves given the allowed range and 
-- score.
limitByRange :: Range -> Performance -> PlayerID -> [MusicMv]
limitByRange r performance p = availableMoves r $ forPlayer p performance

