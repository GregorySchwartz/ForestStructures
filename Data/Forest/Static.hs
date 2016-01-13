
module Data.Forest.Static where

import           Data.Either (either)
import           Data.Graph.Inductive.Basic
import           Data.Traversable (mapAccumL)
import           Data.Tree (drawForest,flatten)
import qualified Data.Map.Strict as S
import qualified Data.Tree as T
import qualified Data.Vector as V
import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Unboxed as VU

import           Biobase.Newick (NewickTree(..),Info(Info))
import qualified Biobase.Newick as N



data TreeOrder = Pre | Post



-- | A static forest structure...

data Forest (p :: TreeOrder) v a where
  Forest :: (VG.Vector v a) =>
    { label     :: v a
    , parent    :: VU.Vector Int
    , children  :: V.Vector (VU.Vector Int)
    , lsib      :: VU.Vector Int
    , rsib      :: VU.Vector Int
    , roots     :: VU.Vector Int
    } -> Forest p v a

-- instance Show (Forest p a) where

deriving instance (Show a, Show (v a)) => Show (Forest p v a)



-- |
--
-- TODO write addIndicesF to allow us to remove the non-nice 'error'
-- function / 'undefined'.

forestWith :: (VG.Vector v a) => (forall a . [T.Tree a] -> [a]) -> [T.Tree a] -> Forest (p::TreeOrder) v a
forestWith f ts
  = Forest { label    = VG.fromList $ f ss
           , parent   = VU.fromList $ map (\(_,k,_,_) -> k) $ f rs
           , children = V.fromList $ map (\(_,_,cs,_) -> VU.fromList cs) $ f rs
           , lsib     = VU.fromList $ map fst $ tail $ S.elems sb
           , rsib     = VU.fromList $ map snd $ tail $ S.elems sb
           , roots    = VU.fromList $ map fst $ T.levels rr !! 1
           }
  where
    ss = ts
    rs = relationsF (-1) $ addIndicesF 0 ss
    rr = addIndices (-1) $ T.Node (error "forestWith :: this should have been legal") ts
    sb = siblings rr


forestPre :: (VG.Vector v a) => [T.Tree a] -> Forest Pre v a
forestPre = forestWith preorderF


forestPost :: (VG.Vector v a) => [T.Tree a] -> Forest Post v a
forestPost = forestWith postorderF


addIndices :: Int -> T.Tree a -> T.Tree (Int,a)
addIndices k = snd . mapAccumL (\i e -> (i+1, (i,e))) k

addIndicesF :: Int -> [T.Tree a] -> [T.Tree (Int,a)]
addIndicesF k = snd . mapAccumL go k
  where go = mapAccumL (\i e -> (i+1, (i,e)))

relationsF :: Int -> [T.Tree (Int,a)] -> [T.Tree (Int,Int,[Int],a)]
relationsF k ts = [ T.Node (i,k,children sf,l) (relationsF i sf)  | T.Node (i,l) sf <- ts ]
  where children sf = map (fst . T.rootLabel) sf

siblings :: T.Tree (Int,a) -> S.Map Int (Int,Int)
siblings = S.fromList . concatMap (go . map fst) . T.levels
  where go xs = zipWith3 (\l x r -> (x,(l,r))) ((-1):xs) xs (tail xs ++ [-1])
        go :: [Int] -> [(Int,(Int,Int))]

test = do
  let ts = map (addIndices 0 . getNewickTree) $ either error id $ N.newicksFromText t
  let ss = either error id $ N.newicksFromText t
  mapM_ (putStrLn . T.drawTree . fmap show) ts
  putStrLn ""
  mapM_ (mapM_ (putStrLn . show) . postorder) ts
  putStrLn ""
  mapM_ (mapM_ (putStrLn . show) . preorder) ts
  putStrLn ""
  mapM_ (mapM_ print . T.levels) ts
  putStrLn ""
  print (forestPre $ map getNewickTree ss :: Forest Pre V.Vector Info)
  putStrLn ""
  print (forestPost $ map getNewickTree ss :: Forest Post V.Vector Info)
  where t = "((raccoon:19.19959,bear:6.80041):0.84600,((sea_lion:11.99700, seal:12.00300):7.52973,((monkey:100.85930,cat:47.14069):20.59201, weasel:18.87953):2.09460):3.87382,dog:25.46154)Root;"
