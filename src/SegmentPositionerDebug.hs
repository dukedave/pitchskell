module SegmentPositionerDebug where

import Prelude hiding (Left, lines)
import Control.Lens
import Control.Monad.Except(MonadError, void)
import Control.Monad.Primitive
import Data.Foldable
import Data.Int
import Data.Proxy
import Data.Word
import Data.Vector as V hiding ((++))
import Linear
import OpenCV as CV
import OpenCV.Extra.XFeatures2d
import OpenCV.Internal.C.Types
import OpenCV.ImgProc.FeatureDetection
import qualified Data.Text as T

import SegmentPositioner
import Track
import TrackGeometry
import Transform
import Colors
import TrackDebug(drawSegmentArrow)

positionLineDebug :: FrameMat -> Segment -> FrameMat
positionLineDebug frame (Segment tile p t) = exceptError $ do
  let p' = positionTile frame (Segment tile p t)
  let t' = transformTile frame (Segment tile p t)
  let [h, w] = miShape . matInfo $ frame
  withMatM (h ::: w ::: Z) (Proxy :: Proxy 3) (Proxy :: Proxy Word8) white $ \imgM -> do
    void $ matCopyToM imgM zero frame Nothing
    let dot = round $ trackWidth t / 32.0
        putText' str pos color = putText imgM (T.pack str) pos (Font FontHersheySimplex NotSlanted 0.3) color 1 LineType_AA False
        showAngle angle = show (round $ angle / (2*pi) * 360)
    for_ (candidateLines (Segment tile p t) frame) $ \(lineSegment, edge) -> do
      arrowedLine imgM (lineSegmentStart lineSegment) (lineSegmentStop  lineSegment) (edgeColor edge) 1 LineType_AA 0 0.15
      putText' (showAngle $ angleFromPoints $ pointsFromLineSegment lineSegment) ((round <$>) <$> (^._x) $ pointsFromLineSegment lineSegment :: V2 Int32) (edgeColor edge)

    circle imgM  (round <$> p) dot white (-1) LineType_AA 0
    drawSegmentArrow imgM white (Segment tile p t)
    circle imgM  (round <$> p') dot green (-1) LineType_AA 0
    drawSegmentArrow imgM green (Segment tile p' t')

  where
    edgeColor LeftEdge {} = green
    edgeColor RightEdge {} = red

positionCircleDebug :: FrameMat -> Segment -> FrameMat
positionCircleDebug frame (Segment tile p t) = exceptError $ do
  let p' = positionTile frame (Segment tile p t)
  let [h, w] = miShape . matInfo $ frame
  withMatM (h ::: w ::: Z) (Proxy :: Proxy 3) (Proxy :: Proxy Word8) white $ \imgM -> do
    void $ matCopyToM imgM zero frame Nothing
    let dot = round $ trackWidth t / 32.0
    for_ (candidateCircles (Segment tile p t) frame) $ \c -> circle imgM (round <$> c :: V2 Int32) dot blue 1 LineType_AA 0

    circle imgM  (round <$> p) dot white (-1) LineType_AA 0
    circle imgM  (round <$> p') dot green (-1) LineType_AA 0

showHough :: Transform -> FrameMat -> FrameMat
showHough t frame = exceptError $ do
  edgesBgr <- cvtColor gray bgr (toEdges frame)
  let [h, w] = miShape . matInfo $ frame
  withMatM (h ::: w ::: Z) (Proxy :: Proxy 3) (Proxy :: Proxy Word8) white $ \imgM -> do
      void $ matCopyToM imgM zero edgesBgr Nothing
      let lines' = lines frame
      for_  lines' $ \lineSegment -> line imgM (lineSegmentStart lineSegment) (lineSegmentStop  lineSegment) red 2 LineType_8 0

      imgG <- cvtColor bgr gray frame
      let minRadius = round $ innerCornerCircleRadius t * 0.95
      let maxRadius = round $ innerCornerCircleRadius t * 1.05
      let dot = round $ trackWidth t / 32.0
      circles' <- houghCircles 2 1 Nothing (Just 20) (Just minRadius) (Just maxRadius) imgG
      for_ circles' $ \c -> do
        circle imgM (round <$> circleCenter c :: V2 Int32) (round (circleRadius c)) blue 1 LineType_AA 0
        circle imgM (round <$> circleCenter c :: V2 Int32) dot green (-1) LineType_AA 0

showInpaintWalls :: FrameMat -> FrameMat
showInpaintWalls frame = exceptError $ do
  let mask = inpaintWallsMask frame
  maskBGR <- cvtColor gray bgr mask
  let inpainted = inpaintWalls frame

  let [h, w] = miShape . matInfo $ frame
  withMatM (h ::: (w*3) ::: Z) (Proxy :: Proxy (S 3)) (Proxy :: Proxy (S Word8)) transparent $ \imgM -> do
    matCopyToM imgM (V2   0   0) frame Nothing
    matCopyToM imgM (V2   w   0) maskBGR Nothing
    matCopyToM imgM (V2 (w*2) 0) inpainted Nothing