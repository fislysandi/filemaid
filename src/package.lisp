(defpackage :filemaid
  (:use :cl)
  (:shadow #:delete)
  (:import-from :uiop
                #:directory-files
                #:ensure-directory-pathname
                #:copy-file)
  (:export
   ;; Data model
   #:file-object
   #:make-file-object
   #:file-object-path
   #:file-object-name
   #:file-object-extension
   #:file-object-size
   #:file-object-created
   #:file-object-modified
   #:file-object-metadata
   #:action-spec
   #:make-action-spec
   #:action-spec-type
   #:action-spec-argument
   #:rule-definition
   #:make-rule-definition
   #:rule-definition-name
   #:rule-definition-from
   #:rule-definition-priority
   #:rule-definition-predicate
   #:rule-definition-actions
   ;; Scanner
   #:scan-directory
   #:make-file-object-from-path
   ;; Filters
   #:file-extension-p
   #:file-name-contains-p
   #:pdf-contains-p
   ;; Rules and DSL
   #:clear-rule-registry
   #:register-rule
   #:registered-rules
   ;; Config
   #:conflict-policy
   #:set-conflict-policy
   #:valid-conflict-policy-p
   #:file-conflict-policy
   #:set-file-conflict-policy
   #:valid-file-conflict-policy-p
   #:*file-conflict-policy*
   #:conflict-resolution-profile-pathname
   #:load-conflict-resolution-profile
   #:save-conflict-resolution-profile
   #:conflict-profile-get
   #:conflict-profile-set
   #:*conflict-resolution-profile-path*
   #:*conflict-resolution-profile*
   #:*default-project-name*
   #:*default-rules-files*
   #:*global-rules-root*
   #:*addons-root*
   #:*enabled-addons*
   #:*autoload-addons*
   #:global-rules-root-pathname
   #:addons-root-pathname
   #:discover-addon-files
   #:resolve-enabled-addon-files
   #:load-addons
   #:resolve-default-rules-file
   #:projects-root-pathname
   #:project-templates-root-pathname
   #:*projects-root*
   #:*project-templates-root*
   #:*init-project-target-resolver*
   #:default-config-pathname
   #:load-default-config
   #:rule
   #:from
   #:priority
   #:when
   #:move
   #:copy
   #:rename
   #:delete
   #:tag
   #:extension
   #:pdf-contains
   ;; Pipeline
   #:plan-rules
   #:collect-conflicts
   #:resolve-conflicts
   #:run-rules
   #:run-rules-with-report
   #:run-rule-on-file
   ;; Actions
   #:apply-action
   ;; Python bridge
   #:set-python-pdf-provider
   #:set-python-integration-enabled
   #:python-integration-enabled-p
   #:python-pdf-contains-p
   ;; CLI
   #:run-cli
   #:main))
