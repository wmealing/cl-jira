;;;; cl-jira.lisp
(defpackage #:cl-jira
  (:use #:cl)
  (:nicknames :jira)
  (:export :request :load-api-key :get-issue :get-comments :add-comment :all-open-accelfix :load-api-key))

(in-package #:cl-jira)

(defparameter *domain* "redhat.com")
(defparameter *root-endpoint* "https://issues.redhat.com/rest/api/latest/")

(defparameter *api-key* "")

(defun load-api-key ()
  (setq *api-key* (uiop:getenv "JIRA_TOKEN")))

(defun set-api-key (api-key)
  (setq *api-key* api-key))

(defun request (method resource &key params data)
  "Do the http request and return an alist.

- method: keyword :GET :POST,
- resource: ids must be either an integer or an url-encoded couple user/project: `/projects/user%2Frepo`
- params: alist of params: '((\"something\" . \"value\")) will be url-encoded.

Example:
(jira:request :GET \"/version\")"

  (let* ((p (and params (str:concat "?" (quri:url-encode-params params))))
         (auth-header (str:concat "Bearer " *api-key*))
         (headers (list (cons "Authorization"  auth-header)
                        (cons "Accept"       "application/json")
                        (cons "Content-Type" "application/json")))
         (url (str:concat *root-endpoint* resource p)))
    ;; (format t "IN REQ - CONNECTING: ~A~%" url)
    ;; (format t "IN REQ - HEADERS: ~A~%" headers )
    ;; (format t "IN REQ - DATA: ~A~%" data )

    (jonathan:parse (dex:request url :method method
                                     :content data
                                     :headers headers
                                     :max-redirects 10))))
(defun get-issue (issue-id &key params data)
  (request :GET (str:concat "issue/" issue-id)))

(defun get-project-components (project-id)
  (request :GET (str:concat "project/" project-id "/components")))

(defun get-comments (issue-id &key params data)
  (request :GET (str:concat "issue/" issue-id "/comment")))

(defun build-comment (comment-text)
  (jonathan:to-json (:body comment-text)))

(defun build-add-label (label-text)
  (jonathan:to-json (list :update (list :labels (list (list  :add  label-text))))) )

(defun add-label (issue-id &key label-text)
  (let* ((label-json (build-add-label label-text)))
    (request :PUT (str:concat "issue/" issue-id ) :data (string-downcase label-json)))  )

(defun get-labels (issue-data)
  (getf (getf issue-data :|fields|) :|labels|))

(defun get-weblinks (issue-id)
  ;; https://{yourInstance}.atlassian.net/rest/api/3/issue/{issue-key}/remotelink
  (request :GET (str:concat "issue/" issue-id "/remotelink") :data nil))

(defun build-component-json (text)
  ;;  (jonathan:to-json (list :update (list :components (list (list  :set (list (list :name text)))))))
  (str:concat "{ \"update\" : { \"components\" : [{\"set\" : [{\"name\" : \"" text  "\"}] }] }}")
  )

(defun set-component (issue-id &key component)
  (let* ((component-json (build-component-json component)))
    (request :PUT (str:concat "issue/" issue-id ) :data component-json)))

(defun add-comment (issue-id &key params comment-text)
  (progn
    (let* ((comment-json (build-comment comment-text)))
      (progn
        (format t "ADD-COMMENT - COMMENT JSON: ~s~%" comment-json )
        (format t "ADD-COMMENT - COMMENT TEXT: ~s~%" comment-text )
        (request :POST (str:concat "issue/" issue-id "/comment" ) :data (format nil "{\"body\" : ~s}" comment-text))))))

(defun all-open-accelfix ()
  (query-with (jonathan:to-json '(("jql" . "project=ACCELFIX and resolution=Unresolved and assignee=rhn-support-wmealing")
                                  ("fields" . ("id" "key"))) :from :alist)))

(defun query-with-raw ( raw-query)
  (query-with (jonathan:to-json `(("jql" . ,raw-query)
                                  ("fields" . ("id" "key"))) :from :alist)))

(defun query-with (jql)
  "
  Run a JQL against the server with configured authentication

  jql = json formatted query.
  See: https://developer.atlassian.com/server/jira/platform/jira-rest-api-examples/#searching-for-issues-examples

  Example:
  (query-with (jonathan:to-json '((\"jql\" . \"project=ACCELFIX and resolution=Unresolved and assignee=rhn-support-wmealing\")"
  (request :POST "search" :data jql))
