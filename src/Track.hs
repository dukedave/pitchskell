module Track where

import Prelude hiding (Left, Right)
import Data.Ratio
import qualified Data.List.Extended as L
import qualified Loop

import Linear.Matrix
import Linear.Vector
import Linear.V2
import Linear.V3

data Tile = Straight | Left | Right deriving (Eq, Enum)
instance Show Tile where
  show Straight = "s"
  show Left = "l"
  show Right = "r"

type Position = V2 Double
type Transform = V2 (V2 Double)

data Segment = Segment
  { tile :: Tile
  , position :: Position
  , transform ::  Transform
  } deriving (Eq)

angleFromTransform :: Transform -> Double
angleFromTransform t =
  let V2 t_x t_y = (t !* V2 1 0)
      a = -atan2 t_y t_x
  in if a >= 0 then a else (pi*2) + a

instance Show Segment where
  show (Segment tile p t) =
    let V2 x y = p
        angle = round $ angleFromTransform t / (2*pi) * 360
      in show tile ++ " " ++ show (round x) ++ "×" ++ show (round y) ++ " " ++ show angle ++ "°"

type Track = Loop.Loop Segment

eye :: Transform
eye = V2 (V2 1 0) (V2 0 1)

start :: Segment
start = Segment Straight zero eye

startFromPT :: Position -> Transform -> Segment
startFromPT = Segment Straight

--startFromVectors :: V2 (V2 Double) -> Segment
--startFromVectors (V2 a b) = startFromPT a ((b - a) ^/ trackUnitVector)

mkTrack :: Segment -> [Tile] -> Track
mkTrack start (Straight : tiles) = Loop.mkLoop $ scanl nextSegment start tiles
mkTrack _ _ = error "track must start with a straight"

parseTrack :: Segment -> String -> Maybe Track
parseTrack start = (mkTrack start <$>) . mapM parseTile . L.chars
  where parseTile = L.findBy [Straight ..] show

nextSegment :: Segment -> Tile -> Segment
nextSegment segment tile = Segment tile (exitPosition segment) (exitTransform segment)

exitPosition :: Segment -> Position
exitPosition (Segment tile p t)
  | tile == Straight = p + (t !* V2 1.613 0)
  | tile == Left = p + (t !* V2 0.82 0.82)
  | tile == Right = p + (t !* V2 0.82 (-0.82))

exitTransform :: Segment -> Transform
exitTransform (Segment tile p t)
  | tile == Straight = t
  | tile == Left = V2 (V2 0 1) (V2 (-1) 0) !*! t
  | tile == Right =  V2 (V2 0 (-1)) (V2 1 0) !*! t
