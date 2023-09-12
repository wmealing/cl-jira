;;;; cl-jira.asd

(asdf:defsystem #:cl-jira
  :description "Describe cl-jira here"
  :author "Wade Mealing"
  :license  "Specify license here"
  :version "0.0.1"
  :serial t
  :depends-on (#:dexador #:jonathan #:quri #:str)
  :components ((:file "package")
               (:file "cl-jira")))
