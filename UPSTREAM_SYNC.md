# Upstream sync status

Upstream repository: `faroukbmiled/RyukGram`

Audited upstream public `main`: `fc0fbfc736a493def3089a78de4991b92db3bc46`

Our repository contains that exact commit and is not behind the public upstream branch. The commits after that baseline are RyukGram Pro-specific changes, including:

- credited Reel/feed repost flow
- Instagram 434 repost media crash guards
- in-process Instagram composer automation
- optional FFmpegKit runtime behavior
- LCSign-compatible unsigned thin arm64 releases
- automatic semantic versioning and dylib-only GitHub Releases

The upstream README identifies the official release line as v1.3.2, while the public source manifest remains v1.2.2 and upstream states that source pushes are paused. Consequently, unpublished v1.3.x binary-only changes cannot be merged as source. This fork uses v1.3.2 as its public upstream baseline and applies its own production fixes on top.

Do not replace the custom release workflow or repost implementation during future upstream syncs. Compare from the audited upstream SHA and cherry-pick only source changes that are newer than it.
