(in-package :filemaid)

(register-rule
 (rule organize-images
   (priority 5)
   (from "~/Downloads")
   (when (or (extension "jpg")
             (extension "jpeg")
             (extension "png")
             (extension "webp")))
   (move "~/Pictures/Imported")))

(register-rule
 (rule organize-videos
   (priority 4)
   (from "~/Downloads")
   (when (or (extension "mp4")
             (extension "mov")
             (extension "mkv")))
   (move "~/Videos/Imported")))

(register-rule
 (rule tag-archives
   (priority 1)
   (from "~/Downloads")
   (when (or (extension "zip")
             (extension "tar")
             (extension "gz")))
   (tag "archive")))
