{-# LANGUAGE FlexibleContexts, TypeFamilies #-}


import Control.Monad.Trans (liftIO)
import Control.Monad (liftM,liftM2,unless)
import Hagl.History
import Hagl
import Euterpea
import Translations
import Debug.Trace

-- test data and constants (probably to be removed later)
octv :: Octave
octv = 5

dummyPayoff :: Float
dummyPayoff = 1.0

range = 10

player1 :: SingularScore
player1 = SS { realization = [], future = [Begin (C,4), Main.Rest, Begin (D,4)] }
player2 :: SingularScore
player2 = SS { realization = [], future = [Begin (A,4), Extend (A,4), Main.Rest] }

--
-- Data definitions
--

data Improvise = Improvise

data RMove = Begin Pitch
           | Rest
           | Extend Pitch deriving (Show, Eq)
           -- invariant: Extend implies extending a previous "Begin"
           -- invariant: Extend must have the same pitch as the most recent "Begin"

data SingularScore = SS { realization :: [RMove], 
                          future      :: [RMove] } 
                          deriving Show

data RealizationState = RS { scores       :: [SingularScore], 
                             accumulating :: [RMove] } 
                             deriving Show


start :: RealizationState
start = RS { scores       = [player1, player2], 
             accumulating = [] }

who :: RealizationState -> PlayerID
who rs = length (accumulating rs) + 1

markable :: RealizationState -> [RMove]
markable rs = possMoves $ scores rs !! length (accumulating rs)
--markable rs = [Begin (A,5)]

registerMove :: RealizationState -> RMove -> RealizationState
registerMove rs mv = let newRS = RS { scores       = scores rs, 
                                      accumulating = mv : accumulating rs}
                      in if length (accumulating newRS) == length (scores newRS)
                         then progress newRS
                         else newRS

progress :: RealizationState -> RealizationState
progress rs = let newPlayers = progressHelper (scores rs) (reverse (accumulating rs))
              in RS {scores = newPlayers, accumulating = []}


progressHelper :: [SingularScore] -> [RMove] -> [SingularScore]
progressHelper []     []       = []
progressHelper (p:ps) (mv:mvs) = SS { realization = mv:realization p, 
                                      future      = drop 1 (future p)} :progressHelper ps mvs

possMoves :: SingularScore -> [RMove]
possMoves SS { realization = _             , future = [] }         = []
possMoves SS { realization = m@(Begin r:rs), future = Begin f:fs } = generateMoves f ++ rangedMoves m ++ [Extend r, Main.Rest]
possMoves SS { realization = m             , future = Begin f:fs } = generateMoves f ++ rangedMoves m ++           [Main.Rest]
possMoves SS { realization = m@(Begin r:rs), future = _ }          =                    rangedMoves m ++ [Extend r, Main.Rest]
possMoves SS { realization = m             , future = _ }          =                    rangedMoves m ++           [Main.Rest]
-- TODO UNION THE LISTS!!!


rangedMoves :: [RMove] -> [RMove]
rangedMoves (Begin p:prev) = generateMoves p
rangedMoves (_      :prev) = rangedMoves prev
rangedMoves _              = []                            


-- returns a list of RMoves range number of halfsteps above & below p
generateMoves :: Pitch -> [RMove]
generateMoves p =
    let genMoves _ _ 0 = []
        genMoves p f n = let m = f p
                         in Begin m : genMoves m f (n-1)
    in Begin p : genMoves p halfStepUp range ++ genMoves p halfStepDown range


end :: RealizationState -> Bool
end rs = null (accumulating rs) && null (future (head (scores rs)))

type Interval = Int
type IntPreference = (Interval, Float)


intPref :: [IntPreference] -> Int -> Float
intPref prefs i = foldr f 0 prefs
    where f (interval, pay) acc = if i == interval then pay + acc else acc

rmoveInterval :: RMove -> RMove -> Maybe Interval
rmoveInterval (Begin p1)  (Begin p2)  = Just $ interval p1 p2
rmoveInterval (Begin p1)  (Extend p2) = Just $ interval p1 p2
rmoveInterval (Extend p1) (Begin p2)  = Just $ interval p1 p2
rmoveInterval _           _           = Nothing

onePlayerPay :: [RMove] -> [[RMove]] -> [IntPreference] -> Float
onePlayerPay [] _ _ = 0
onePlayerPay _ [] _ = 0
onePlayerPay (me:rs) others ps = foldr f 0 others + onePlayerPay rs others ps
    where f (m:ms) acc = case rmoveInterval me m of
                            Nothing -> acc
                            Just a  -> acc + intPref ps (abs a)

pay :: [IntPreference] -> RealizationState -> Payoff
pay prefs rs = ByPlayer $ p [] (scores rs) prefs
    where p _      []         _     = []
          p before (me:after) prefs = 
              onePlayerPay (realization me) (map realization (before ++ after)) prefs : 
              p (me:before) after prefs

-- Game instance
instance Game Improvise where
  type TreeType Improvise = Discrete
  type Move  Improvise = RMove
  type State Improvise = RealizationState
  gameTree _ = stateTreeD who end markable registerMove (pay samplePrefs) start

samplePrefs = [(4 , 4.0)]

main = evalGame Improvise guessPlayers (run >> printSummaryOfGame 1)
   where run = step >>= maybe run (\p -> printGame >> playMusic >>return p)



-- Players
guessPlayers :: [Hagl.Player Improvise]
guessPlayers = ["A" ::: return (Begin (C, 4)), 
                "B" ::: return (Begin (E, 4))]

-- Printing
printGame :: GameM m Improvise => m ()
printGame = gameState >>= liftIO . putStrLn . show

-- Music generation
playMusic :: (GameM m g, Show (Move g)) => m ()
playMusic = do
    (mss, _) <- liftM (forGame 1) summaries
    --let jams = composeMusic translate mss
    --liftIO $ Euterpea.play $ jams
    liftIO $ Euterpea.play $ note wn (Ass, octv)
    return ()


-- TODO: need a translation functions for [[RMove]] -> Music Pitch (or Music a)
composeMusic :: Game g => ([[Move g]] -> Music Pitch) -> MoveSummary (Move g) -> Music Pitch
composeMusic translate mss = translate (map everyTurn (everyPlayer mss))


-- | String representation of a move summary.
showMoveSummary :: (Game g, Show (Move g)) =>
  ByPlayer (Hagl.Player g) -> MoveSummary (Move g) -> String
showMoveSummary ps mss = (unlines . map row)
                         (zip (everyPlayer ps) (map everyTurn (everyPlayer mss)))
  where row (p,ms) = "  " ++ show p ++ " moves: " ++ showSeq (reverse (map show ms))
