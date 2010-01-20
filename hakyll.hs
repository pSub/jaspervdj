module Main where

import Text.Hakyll (hakyll)
import Text.Hakyll.Render
import Text.Hakyll.Util (trim, link)
import Text.Hakyll.File (getRecursiveContents, directory, removeSpaces)
import Text.Hakyll.Renderables (createPagePath, createCustomPage)
import Text.Hakyll.Tags (readTagMap, renderTagCloud, renderTagLinks)
import Text.Hakyll.Context (renderDate, renderValue, ContextManipulation)
import qualified Data.Map as M
import Data.List (sort, intercalate)
import Control.Monad (liftM, mapM_)
import Control.Monad.Reader (liftIO)
import Data.Either (Either(..))

main = hakyll $ do
    liftIO $ putStrLn "Copying static directories and compressing css..."
    directory static "images"
    directory static "js"
    directory css "css"
    static "favicon.ico"

    liftIO $ putStrLn "Finding posts..."
    postPaths <- liftM (reverse . sort) $ getRecursiveContents "posts"
    let renderablePosts = map createPagePath postPaths

    liftIO $ putStrLn "Getting tags..."
    tagMap <- readTagMap postPaths

    liftIO $ putStrLn "Generating index..."
    let recentPosts = renderAndConcatWith postManipulation
                                          ["templates/postitem.html"]
                                          (take 3 renderablePosts)
    renderChain ["index.html", "templates/default.html"] $
        createCustomPage "index.html" ("templates/postitem.html" : postPaths)
            [("title", Left "Home"), ("posts", Right recentPosts),
             ("tagcloud", Left $ renderTagCloud tagMap tagToURL 100 120)]

    liftIO $ putStrLn "Generating rss feed..."
    let recentItems = renderAndConcatWith postManipulation
                                          ["templates/rssitem.xml"]
                                          (take 5 renderablePosts)
    renderChain ["templates/rss.xml"] $
        createCustomPage "rss.xml" ("templates/rssitem.xml" : postPaths) [("items", Right recentItems)]

    liftIO $ putStrLn "Generating general post list..."
    renderPostList "posts.html" "All posts" postPaths

    liftIO $ putStrLn "Generating all posts..."
    mapM_ (renderChainWith postManipulation ["templates/post.html", "templates/default.html"])
          renderablePosts

    liftIO $ putStrLn "Creating tag post lists..."
    mapM_ (\(t, p) -> renderPostList (tagToURL t)
                        ("Posts tagged " ++ t) (sort $ reverse p)) $ M.toList tagMap

    liftIO $ putStrLn "Generating simple pages..."
    mapM_ (renderChain ["templates/default.html"] . createPagePath)
            [ "contact.markdown"
            , "projects.markdown"
            , "404.html"
            ]

    liftIO $ putStrLn "Succes!"

tagToURL :: String -> String
tagToURL tag = "$root/tags/" ++ (removeSpaces tag) ++ ".html"

postManipulation :: ContextManipulation
postManipulation = renderTagLinks tagToURL
                 . renderDate "prettydate" "%B %e, %Y" "Date unknown"

renderPostList url title posts = do
    liftIO $ putStrLn $ "Generating post list " ++ title ++ "..."
    let postItems = renderAndConcatWith postManipulation ["templates/postitem.html"] $ map createPagePath posts
    renderChain ["posts.html", "templates/default.html"] $
        createCustomPage url ("templates/postitem.html" : posts)
        [("title", Left title), ("posts", Right postItems)]
