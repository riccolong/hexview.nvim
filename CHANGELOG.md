# Changelog: Performance & Search Update

**🚀 Major Performance Boost**

* **Batch Rendering:** Large files now load instantly. We switched from line-by-line rendering to a single-pass update, drastically reducing API calls.


**Memory Optimization:** Reduced memory usage by storing data as raw strings instead of large tables.

 
**Faster Saving:** Saving files is now buffered and much quicker.



**✨ New Features**

* **Hex Search:** You can now search for hex sequences (e.g., `AA BB`).
* Press `/` to search.
* Press `n` to find the next occurrence.





**🛠 Under the Hood**
 
**Optimized Rendering:** Switched to native syntax highlighting for offsets to improve scrolling performance.
 
**Sparse Edits:** Only modified bytes are stored in memory, keeping the plugin lightweight.
