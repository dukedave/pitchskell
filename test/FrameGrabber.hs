{-# language DataKinds #-}

module FrameGrabber where

import Control.Monad ( replicateM )
import Control.Monad.Loops ( unfoldM )
import qualified OpenCV as CV
import Data.Word
import OpenCV.TypeLevel
import OpenCV.VideoIO.Types
import OpenCV.Internal.VideoIO.Types
import OpenCV.Unsafe
import Data.Maybe

type TestMat = CV.Mat ('S ['D, 'D]) ('S 3) ('S Word8)

withFile :: FilePath -> IO CV.VideoCapture
withFile fp = do
    cap <- CV.newVideoCapture
    CV.exceptErrorIO $ CV.videoCaptureOpen cap (CV.VideoFileSource fp Nothing)
    return cap

getFrames :: FilePath -> IO [TestMat]
getFrames fp = do
    cap <- withFile fp

    -- videoCaptureRetrieve is supposed to return Nothing at the end of the file
    -- But it's broken on MacOS: https://stackoverflow.com/questions/13798795/opencv-capture-loops-video-does-not-detect-last-frame
    -- So just use the frame count instead.

    frameCount <- CV.videoCaptureGetI cap VideoCapPropFrameCount
    map unsafeCoerceMat . catMaybes <$> replicateM (fromIntegral frameCount) (grabRetrieve cap)

    where grabRetrieve cap = CV.videoCaptureGrab cap >> CV.videoCaptureRetrieve cap

withFrames :: FilePath -> (TestMat -> a) -> IO [a]
withFrames fp f =  map f <$> getFrames fp

withFramesM :: FilePath -> (TestMat -> IO a) -> IO [a]
withFramesM fp f = mapM f =<< getFrames fp
