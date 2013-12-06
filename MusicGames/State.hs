module State where
import Euterpea

-- | An Improvise move is a fixed-duration musical event. A player may start
-- playing a new note of any pitch, continue or extend the previous note, or 
-- rest for the duration. 
-- Invariants: Extend implies extending a previous Begin; an Extend may not
--             follow a Rest
--             Extend must have the same pitch as the most recent Begin
data MusicMv = Begin Pitch
             | Extend Pitch 
             | Rest deriving Eq

-- | A singular score represents an individual player. The realization is a 
-- list of musical events that have already occurred, i.e. the player's
-- interpretation of the score thus far (most recent event first). The future 
-- is a list of the upcoming events, i.e. the remaining portion of her score.  
data SingularScore = SS { realization :: [MusicMv]
                        , future      :: [MusicMv] } deriving Show

-- | A realization state represents the state of the game at any moment.  The
-- scores represents all the individual players; accumulating keeps track of
-- moves that have been "decided upon" but not yet registered.
data RealizationState = RS { scores       :: [SingularScore]
                           , accumulating :: [MusicMv] } deriving Show


instance Show MusicMv where --use 20 chars
    show (Begin p)  = take 20 $ "Begin  " ++ show p++ (repeat ' ')
    show (Extend p) = take 20 $ "Extend " ++ show p ++ (repeat ' ')
    show State.Rest = take 20 $ "Rest" ++ (repeat ' ')
                            
