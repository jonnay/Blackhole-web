;; This program is free software: you can redistribute it and/or modify
 ;; it under the terms of the GNU General Public License as published by
 ;; the Free Software Foundation, either version 3 of the License, or
 ;; (at your option) any later version.
 
 ;; This program is distributed in the hope that it will be useful,
 ;; but WITHOUT ANY WARRANTY; without even the implied warranty of
 ;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ;; GNU General Public License for more details.
 
 ;; You should have received a copy of the GNU General Public License
 ;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 
 ;; Copyright 2009 Andrew Whaley

 ;; A Pure Scheme MySQL client for Gambit, use like this :-

 ;; (with-connection (sql-connect "localhost" 3306 "test" "fred" "fred")
 ;;    (pp (sql-execute "SELECT * FROM USER"))
 ;;  )
 ;; Please see the test case at the bottom of this file.

 ;; Version 0.2 
 ;; -----------
 ;; Now supports prepared statements and some binary data types. It doesn't support BLOB's or long strings yet.
 ;; Also doesn't support retrieval of FLOAT and DOUBLE types through the binary protocol i.e. prepared statements
 ;; Use DECIMAL instead as these are returned as strings.
 ;; It probably doesn't support large result sets either as these will require supplemental fetches which
 ;; hasn't been implemented.
 ;; Please note that when using dynamic statements all data is returned as a string.


(include "sha1.scm")
(include "sql.scm")

;; Specifies if you want debug output from the protocol
(define mysql-debug #f)

;;; 
;;;; MySQL Connections
;;;  
(define-structure mysql-connection
                  socket
                  packet-sequence)


;;;
;;;; Packet Definitions
;;;
;; 

;; Creates a structure for the packet data and a reader function
(define-macro define-packet (lambda (packet-name . vars)               
        (list 'begin 
               ;; Structure 
               (append `(define-structure ,(string->symbol (string-append (symbol->string packet-name) "-packet")))
                  (map car vars))
               
               ;; Reader 
               (append `(define (,(string->symbol (string-append "read-" (symbol->string packet-name) "-packet")))) 
                   (list (append  '(let*) (list (map (lambda (v)
                                                      (append (list (car v) (append (list (string->symbol (string-append "read-" (cadr v)))) (cddr v))))) 
                                                                              
                                                    vars)) 
                                  (list (append (list (string->symbol (string-append "make-" (symbol->string packet-name) "-packet"))) 
                                                        (map car vars))
                                                        )))))))


;; Protocol Data Packets 
(define-packet handshake 
    (protocol-version    "u8")
    (server-version      "asciiz")
    (thread-id           "u32")
    (scramble-buff       "asciiz")
    (server-capabilities "u16")
    (server-language     "u8")
    (server-status       "u16")
    (ignore              "u8vector" 13)  
    (scramble-buff2      "asciiz"))

(define-packet ok
    (affected-rows       "lcb")
    (insert-id           "lcb")
    (server-status       "u16") 
    (warning-count       "u16")
    (message             "asciiz"))

(define-packet error
    (error-number        "u16") 
    (sql-state           "u8vector" 6)
    (message             "asciiz"))

(define-packet field
    (catalog             "lcs")
    (db                  "lcs")
    (table               "lcs") 
    (original-table      "lcs")
    (name                "lcs") 
    (original-name       "lcs")
    (ignore              "u8")
    (charset-number      "u16") 
    (length              "u32")
    (type                "u8")
    (flags               "u16")
    (decimals            "u8")
    (ignore2             "u8")
    (default             "lcb"))

(define-packet prepared-statement-ok
    (handler-id          "u32")
    (columns             "u16")
    (parameters          "u16"))

(define-packet prepared-parameter
    (type                "u16")
    (flags               "u16")
    (decimals            "u8")
    (length              "u32"))

;;;
;;;; Constants and capabilities
;;; 

;; MySQL Capabilities
(define mysql-capabilities (list
  '(CLIENT_LONG_PASSWORD .         1)  ;;   new more secure passwords 
  '(CLIENT_FOUND_ROWS .            2)  ;;   Found instead of affected rows 
  '(CLIENT_LONG_FLAG  .            4)  ;;   Get all column flags 
  '(CLIENT_CONNECT_WITH_DB .       8)  ;;   One can specify db on connect 
  '(CLIENT_NO_SCHEMA .            16)  ;;   Don't allow database.table.column 
  '(CLIENT_COMPRESS .             32)  ;;   Can use compression protocol 
  '(CLIENT_ODBC .                 64)  ;;   Odbc client 
  '(CLIENT_LOCAL_FILES .         128)  ;;   Can use LOAD DATA LOCAL 
  '(CLIENT_IGNORE_SPACE .        256)  ;;   Ignore spaces before '(' 
  '(CLIENT_PROTOCOL_41 .         512)  ;;   New 4.1 protocol 
  '(CLIENT_INTERACTIVE .        1024)  ;;   This is an interactive client 
  '(CLIENT_SSL .                2048)  ;;   Switch to SSL after handshake 
  '(CLIENT_IGNORE_SIGPIPE .     4096)  ;;   IGNORE sigpipes 
  '(CLIENT_TRANSACTIONS .       8192)  ;;   Client knows about transactions 
  '(CLIENT_RESERVED .          16384)  ;;   Old flag for 4.1 protocol  
  '(CLIENT_SECURE_CONNECTION . 32768)  ;;   New 4.1 authentication 
  '(CLIENT_MULTI_STATEMENTS .  65536)  ;;   Enable/disable multi-stmt support 
  '(CLIENT_MULTI_RESULTS .    131072))) ;;  Enable/disable multi-results 

(define (get-capabilities x)
  (let nxt ((c '()) (cl mysql-capabilities))
    (cond
      ((null? cl) c)
      ((> (bitwise-and x (cdar cl)) 0) 
         (nxt (cons (caar cl) c) (cdr cl)))
      (else (nxt c (cdr cl))))
    )  
  )

(define (set-capabilities caps)
  (let nxt ((x 0) (lst caps))
    (cond
     ((null? lst) x)
     ((assq (car lst) mysql-capabilities) (nxt (bitwise-ior x (cdr (assq (car lst) mysql-capabilities))) (cdr lst)))
     (else (nxt x (cdr lst)))))
  )

;; MySQL Commands
(define COM_SLEEP                #x00)  ;;  (none, this is an internal thread state)
(define COM_QUIT                 #x01)  ;;   mysql_close
(define COM_INIT_DB              #x02)  ;;   mysql_select_db 
(define COM_QUERY                #x03)  ;;   mysql_real_query
(define COM_FIELD_LIST           #x04)  ;;   mysql_list_fields
(define COM_CREATE_DB            #x05)  ;;   mysql_create_db (deprecated)
(define COM_DROP_DB              #x06)  ;;   mysql_drop_db (deprecated)
(define COM_REFRESH              #x07)  ;;   mysql_refresh
(define COM_SHUTDOWN             #x08)  ;;   mysql_shutdown
(define COM_STATISTICS           #x09)  ;;   mysql_stat
(define COM_PROCESS_INFO         #x0a)  ;;   mysql_list_processes
(define COM_CONNECT              #x0b)  ;;  (none, this is an internal thread state)
(define COM_PROCESS_KILL         #x0c)  ;;   mysql_kill
(define COM_DEBUG                #x0d)  ;;   mysql_dump_debug_info
(define COM_PING                 #x0e)  ;;   mysql_ping
(define COM_TIME                 #x0f)  ;;  (none, this is an internal thread state)
(define COM_DELAYED_INSERT       #x10)  ;;  (none, this is an internal thread state)
(define COM_CHANGE_USER          #x11)  ;;   mysql_change_user
(define COM_BINLOG_DUMP          #x12)  ;;  (used by slave server / mysqlbinlog)
(define COM_TABLE_DUMP           #x13)  ;;  (used by slave server to get master table)
(define COM_CONNECT_OUT          #x14)  ;;  (used by slave to log connection to master)
(define COM_REGISTER_SLAVE       #x15)  ;;  (used by slave to register to master)
(define COM_STMT_PREPARE         #x16)  ;;   mysql_stmt_prepare
(define COM_STMT_EXECUTE         #x17)  ;;   mysql_stmt_execute
(define COM_STMT_SEND_LONG_DATA  #x18)  ;;   mysql_stmt_send_long_data
(define COM_STMT_CLOSE           #x19)  ;;   mysql_stmt_close
(define COM_STMT_RESET           #x1a)  ;;   mysql_stmt_reset
(define COM_SET_OPTION           #x1b)  ;;   mysql_set_server_option
(define COM_STMT_FETCH           #x1c)  ;;   mysql_stmt_fetch


;; Field Types
;; 
(define DECIMAL 0)  
(define TINY 1)
(define SHORT 2)  
(define LONG 3)  
(define FLOAT 4)
(define DOUBLE 5)  
(define NULL 6)  
(define TIMESTAMP 7)  
(define LONGLONG 8)  
(define INT24 9) 
(define DATE 10) 
(define TIME 11) 
(define DATETIME 12) 
(define YEAR 13) 
(define NEWDATE 14) 
(define NEWDECIMAL 246)
(define ENUM 247)
(define SET 248)
(define TINY_BLOB 249)
(define MEDIUM_BLOB 250)
(define LONG_BLOB 251)    
(define BLOB 252)
(define VAR_STRING 253)
(define STRING 254)
(define GEOMETRY 255)
       
;;;
;;;; Readers and writers
;;;    

;; Reader and Writer functions for individual data types
(define (read-u16)
  (let* ((b1 (read-u8)) (b2 (read-u8)))
    (+ b1 (* b2 256)))
  )

(define (write-u16 n)
  (write-u8 (fxand n #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 8) #xff))
  )

(define (read-u24)
  (let* ((b1 (read-u8)) (b2 (read-u8)) (b3 (read-u8))) 
    (+ b1 (* b2 256) (* b3 256 256)))
  )

(define (write-u24 n)
  (write-u8 (fxand n #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 8) #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 16) #xff))
  )

(define (read-u32)
  (let* ((b1 (read-u8)) (b2 (read-u8)) (b3 (read-u8)) (b4 (read-u8))) 
    (+ b1 (* b2 256) (* b3 256 256) (* b4 256 256 256)))
  )

(define (write-u32 n)
  (write-u8 (fxand n #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 8) #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 16) #xff))
  (write-u8 (fxand (fxarithmetic-shift-right n 24) #xff))
  )

;; Reading and writing ASCII strings
(define (read-asciiz)
  (let nxt ((s ""))
    (let ((b (read-u8)))      
    (cond
      ((eof-object? b) s)  
      ((eqv? b 0) s)
      (else (nxt (string-append s (string (integer->char b))))))))
  )

(define (write-asciiz str)
  (write-substring str 0 (string-length str))
  (write-u8 0)
  )

(define (write-ascii str)
  (write-substring str 0 (string-length str))
  )

;; Reading and writing MySQL Length Coded Binary
(define (read-lcb)
  (let ((x (read-u8)) (u64 (make-u8vector 8 0)))
    (cond 
      ((<= x 250) x)
      ((= x 251) 0)
      ((= x 252) (read-u16))
      ((= x 253) (read-u24))
      (else (read-u8vector 8))))
  )

(define (write-lcb x)
  (cond 
      ((= x 0) (write-u8 251))       
      ((and (> x 0) (<= x 250)) (write-u8 x))
      ((and (> x 250) (< 65536)) (write-u8 252) (read-u16 x))
      (else (write-u8 253) (write-u24 x))))

(define (read-lcs)
  (let ((l (read-lcb)))
    (if (> l 0)
      (list->string (map integer->char (u8vector->list (read-u8vector l))))
      "")))

(define (write-lcs str)
  (write-lcb (string-length str))
  (write-ascii str)
  )
 
(define (read-u8vector size)
  (let ((v (make-u8vector size 0)))
    (read-subu8vector v 0 size)
    v)
  )

(define (write-u8vector v)
  (let ((s (u8vector-length v)))
    (write-u8 s)
    (write-subu8vector v 0 s)
    ))

;;;
;;;; Packet IO handling
;;;

;; Read and Write Protocol Packets
(define (mysql-read-packet connection)
  (let* ((port (mysql-connection-socket connection))
         (b0 (read-u8 port)) (b1 (read-u8 port)) (b2 (read-u8 port)) (n (read-u8 port))
         (pkt-size (+ b0 (* b1 256) (* b2 65536)))
         (packet (make-u8vector pkt-size 0)))         
    (read-subu8vector packet 0 pkt-size port)
    (mysql-connection-packet-sequence-set! connection (+ n 1))
    (if mysql-debug (begin
      (display (string-append "Packet received: " (number->string pkt-size) " bytes:"))(newline)
      (write packet)(newline)(newline)))                        
    packet)     
  )

(define (mysql-write-packet packet connection)
  (let ((port (mysql-connection-socket connection))
        (pkt-size (u8vector-length packet)))
    (write-u8 (fxand pkt-size #xff) port)
    (write-u8 (fxand (fxarithmetic-shift-right pkt-size 8) #xff) port)
    (write-u8 (fxand (fxarithmetic-shift-right pkt-size 16) #xff) port)
    (write-u8 (mysql-connection-packet-sequence connection) port)
    (write-subu8vector packet 0 pkt-size port)    
    (force-output port)
    (mysql-connection-packet-sequence-set! connection (+ (mysql-connection-packet-sequence connection) 1))
    (if mysql-debug (begin
      (display (string-append "Packet sent: " (number->string pkt-size) " bytes:"))(newline)
      (write packet)(newline)(newline))))
  )


;;;
;;;; Password functions
;;;

;; Old password hashing algorithm 
(define (hash password)
  (let ((nr 1345345333) (add 7) (nr2 #x12345671))
    (let p ((pwd (string->list password)))
      (cond 
        ((null? pwd) #t)
        ((char=? (car pwd) #\space) (p (cdr pwd)))
        (else
           (let ((tmp (bitwise-and (char->integer (car pwd)) #xff)))
             (set! nr (bitwise-xor nr 
                         (+ (* (+ (bitwise-and nr 63) add) tmp) (arithmetic-shift nr 8))))
             (set! nr2 (+ nr2 (bitwise-xor (arithmetic-shift nr2 8) nr)))
             (set! add (+ add tmp))
             (p (cdr pwd))))))
    (cons (bitwise-and nr #x7fffffff) (bitwise-and nr2 #x7fffffff)))  
  )

;; Old password encryption algorithm uses hash above
(define (crypt password seed)
  (list->string 
  (let* ((pw (hash seed))
         (msg (hash password))
         (max #x3fffffff)
         (seed1 (modulo (bitwise-xor (car pw) (car msg)) max))
         (seed2 (modulo (bitwise-xor (cdr pw) (cdr msg)) max))
         (round1 (let n ((s (string->list seed)) (c '()))
                     (cond
                      ((null? s) c)
                      (else
                       (set! seed1 (modulo (+ (* seed1 3) seed2) max))
                       (set! seed2 (modulo (+ seed1 seed2 33) max))
                       (let* ((d (/ seed1 max))
                              (b (floor (+ (* d 31) 64))))
                         (n (cdr s) (append c (list b)))
                         ))))))
    (set! seed1 (modulo (+ (* seed1 3) seed2) max))
    (set! seed2 (modulo (+ seed1 seed2 33) max))
    
    (let* ((d (/ seed1 max))
           (b (floor (* d 31) )))
      (let nxt ((s round1) (e '()))
        (cond
          ((null? s) e)
          (else
            (nxt (cdr s) (append e (list (integer->char (bitwise-xor (car s) b))))))))))))


;; CLIENT_SECURE_CONNECTION new authentication method - uses SHA1 (external dependency)
(define (scramble password seed)
  (let* ((stage1 (digest-string password 'sha-1 'u8vector))
         (stage2 (digest-u8vector stage1 'sha-1 'u8vector))
         (msg    (digest-u8vector (u8vector-append (list->u8vector (map char->integer (string->list seed))) stage2) 'sha-1 'u8vector)))
    (list->u8vector (map bitwise-xor (u8vector->list msg) (u8vector->list stage1))))  
  )

;;;
;;;; High level message handling 
;;;

(define (make-client-authentication-packet 
           client-flags
           max-packet-size
           charset-number
           user
           password
           database-name)
    (let ((filler (make-u8vector 23 0)))
      (with-output-to-u8vector '() (lambda ()
        (write-u32 client-flags)
        (write-u32 max-packet-size)
        (write-u8 charset-number)
        (write-subu8vector filler 0 23)
        (write-asciiz user)
        (cond 
          ((u8vector? password) (write-u8vector password)) ;; Protocols > 4.1
          ((string? password) (write-asciiz password)) ;; 4.1 protocol          
          (else (write-u8 0))) ;; No password                             
        (write-asciiz database-name))))                               
  )

(define (make-command-packet command . arg)
   (with-output-to-u8vector '() (lambda ()
      (write-u8 command)
      (if (not (null? arg))
          (if (number? (car arg))
              (write-u32 (car arg))
              (write-ascii (car arg)))))))
           

(define (make-statement-execute-packet id params)
  (with-output-to-u8vector '() (lambda ()
    (write-u8 COM_STMT_EXECUTE)
    (write-u32 id)             ;; statement id
    (write-u8 0)               ;; flags
    (write-u32 1)              ;; iteration count - not used
    ;;(write-null-bitmap params) ;; Null Bitmap for paramters
    (write-u8 0)   ;; No nulls upto 8 params
    (write-u8 1)               ;; New parameters bound
                                 
    (for-each (lambda (p)      ;; Parameter types
                (cond 
                  ((integer? p) (write-u16 LONG)) ;; Signed integer                  
                  (else (write-u16 (bitwise-ior VAR_STRING 32768)))) ;; Everything else a string                
                ) 
              params)
                                 
    (for-each (lambda (p)      ;; Parameter values
                (cond 
                   ((integer? p) (write-u32 p))   ;; Integer can go in binary u32
                   ((number? p) (write-lcs (number->string p))) ;; Convert floats to string
                   (else (write-lcs p)))  ;; Everything else is a string
                )
              params)
    )))


;; Read response packet
(define (mysql-read-response packet)
  (with-input-from-u8vector packet (lambda ()
    (let ((field-count (read-u8)))
      (cond 
        ((eqv? field-count 0)  ;; Response OK packet     
           (read-ok-packet))
        ((eqv? field-count #xff) ;; Error packet
           (let ((ep (read-error-packet))) 
           (raise (make-sql-error (error-packet-error-number ep) (error-packet-message ep)))))
        (else field-count)
        ))    
  )))

;; Read response to prepare statement
(define (mysql-read-prepared-response packet)
  (with-input-from-u8vector packet (lambda ()
    (let ((field-count (read-u8)))
      (cond 
        ((eqv? field-count 0)  ;; Response OK packet     
           (read-prepared-statement-ok-packet))
        (else ;; Error packet
           (let ((ep (read-error-packet))) 
           (raise (make-sql-error (error-packet-error-number ep) (error-packet-message ep)))))
        ))    
  )))

(define (if-secure-connection? handshake)
  (memv 'CLIENT_SECURE_CONNECTION (get-capabilities (handshake-packet-server-capabilities handshake)))
  )

;; Converts a u8vector v into a list of bits of size n
(define (bits->list v n o)
  (let nxt ((x (- n 1)) (r '()))
    (cond 
      ((< x 0) r)
      (else (nxt (- x 1) (cons    
                           (let* ((byte (quotient (+ x o) 8))
                                  (bit (- (+ x o) (* byte 8))))
                             (bit-set? bit (u8vector-ref v byte))) 
                           r
                          ))))))

;; Reads the result set 
(define (mysql-read-result-set connection field-count)
  (letrec (
           (read-fields (lambda (fc fields)
             (cond 
               ((= fc 0) fields)
               (else (read-fields (- fc 1) 
                         (append fields (list  
                              (with-input-from-u8vector (mysql-read-packet connection) read-field-packet ))))))))
           (read-row (lambda (packet fields)
              (with-input-from-u8vector packet (lambda ()
                ;; Check for binary data row
                (let ((x (read-u8)))
                         (if (= x 0) 
                             ;; Read Null bitmaps
                             (let ((nulls (bits->list (read-u8vector (+ (quotient (+ (length fields) 2) 8) 1)) 
                                                      (length fields) 
                                                      2)))
                               ;; Read binary column data
                               (map (lambda (f n)
                                      (let ((t (field-packet-type f)))
                                        (cond                                        
                                          (n 'NULL) ;; NULL value                                          
                                          ((= t NEWDECIMAL) (string->number (read-lcs) 10))
                                          ((= t TINY) (read-u8))
                                          ((= t SHORT) (read-u16))
                                          ((= t INT24) (read-u24))
                                          ((= t LONG) (read-u32))
                                          ((= t DATETIME) 
                                             (let* ((l (read-u8)) (year (read-u16)) (month (read-u8)) (date (read-u8))
                                                    (hour (read-u8)) (min (read-u8)) (sec (read-u8)))
                                               (make-sql-datetime year month date hour min sec)))                                           
                                          ((= t DATE) 
                                             (let* ((l (read-u8)) (year (read-u16)) (month (read-u8)) (date (read-u8)))
                                               (make-sql-date year month date)))                                           
                                          ((= t TIME) 
                                             (let* ((l (read-u8)) (hour (read-u8)) (min (read-u8)) (sec (read-u8)))
                                               (make-sql-time hour min sec)))                                           
                                          (else (read-lcs)))))
                                    fields nulls)
                               )
                             ;; Not binary - read character fields all LCS
                             (with-input-from-u8vector packet (lambda () (map (lambda (ignore) (read-lcs)) fields))))))))))                         
                     
    (let ((fields (read-fields field-count '())))     
      (mysql-read-packet connection) ;; EOF packet for field-data            
      (cons (map field-packet-name fields)
           (let next-row ((rows '()))
             (let ((next-packet (mysql-read-packet connection)))
               (cond
                 ((= (u8vector-ref next-packet 0) #xfe) rows) ;; End of data packet
                 (else (next-row (append rows (list (read-row next-packet fields))))))))))))

;;;
;;;; Client API 
;;; 

;; Connects to a MySQL server and database 
(define (mysql-connect host port database-name username password)
  (let* ((s (open-tcp-client (list server-address: host port-number: port)))
         (connection (make-mysql-connection s 0))
         (handshake (with-input-from-u8vector (mysql-read-packet connection) read-handshake-packet))
         (seed (string-append
                            (handshake-packet-scramble-buff handshake)
                            (handshake-packet-scramble-buff2 handshake)))
         (p (cond
              ((= (string-length password) 0) 0) ;; No password              
              ((if-secure-connection? handshake) (scramble password seed))    ;; New Secure connection password
              (else (crypt password seed))     ;; Older less secure protocol
              )))
    (if mysql-debug (write handshake))
    (mysql-write-packet 
      (make-client-authentication-packet 
        (set-capabilities '(CLIENT_LONG_PASSWORD CLIENT_SECURE_CONNECTION CLIENT_PROTOCOL_41 CLIENT_TRANSACTIONS CLIENT_CONNECT_WITH_DB CLIENT_MULTI_RESULTS))
        (* 255 255 255)
        8       
        username
        p
        database-name) connection)     
    (mysql-read-response (mysql-read-packet connection))
    (mysql-use-database database-name connection)
    connection))


;; Closes the database connection
(define (mysql-close-connection . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest)))) 
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet 
       (make-command-packet COM_QUIT) 
       connection)    
    (close-port (mysql-connection-socket connection))
    )
  )

;; Connects the user to a different database on the server
(define (mysql-use-database database . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest)))) 
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet 
       (make-command-packet COM_INIT_DB database) 
       connection)    
    (mysql-read-response (mysql-read-packet connection))     
    )
  )

;; Issues a dynamic SQL statement i.e. complete SELECT, UPDATE etc 
;; Returns either a result set : a list (rows) of lists (columns) of data. The first row is the column names, data starts on the 2nd row.
;; or an integer indicating how many rows have been updated          
(define (mysql-execute-dynamic-statement select-query . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest)))) 
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet 
       (make-command-packet COM_QUERY select-query) 
       connection)    
    (let ((field-count (mysql-read-response (mysql-read-packet connection))))
      (if (ok-packet? field-count)
        (ok-packet-affected-rows field-count)  ;; Update returns ok packet
        (mysql-read-result-set connection field-count))) ;; Queries return a result set
    ))


;; Prepares a statement for subsequent binding and execution
;; Returns: statement handler id for future bind, execute and close operations.
(define (mysql-prepare-statement query-text . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest)))) 
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet 
       (make-command-packet COM_STMT_PREPARE query-text) 
       connection)        
    
    (let* ((r (mysql-read-prepared-response (mysql-read-packet connection)))
           (p (prepared-statement-ok-packet-parameters r))
           (c (prepared-statement-ok-packet-columns r))
           (t (+ p c (if (> p 0) 1 0) (if (> c 0) 1 0)))) ;; Number of packets to read (columns + parameters + 2 eof packets)
      (let skip ((n t))
        (if (> n 0) (begin 
            (mysql-read-packet connection)
            (skip (- n 1)))))
      (prepared-statement-ok-packet-handler-id r)
      )
    ))

;; Execute a prepared statement
(define (mysql-execute-prepared-statement statement-id parameter-list . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest))))
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet (make-statement-execute-packet statement-id parameter-list) connection)
    
    (let ((field-count (mysql-read-response (mysql-read-packet connection))))
      (if (ok-packet? field-count)
        (ok-packet-affected-rows field-count)  ;; Update returns ok packet
        (mysql-read-result-set connection field-count))) ;; Queries return a result set
    ))

(define mysql-execute-prepared mysql-execute-prepared-statement) ;; Saves on typing

;; Closes the database connection
(define (mysql-close-statement id . rest)
  (let ((connection (if (null? rest) 
                    (current-sql-connection) 
                    (car rest)))) 
    (mysql-connection-packet-sequence-set! connection 0)
    (mysql-write-packet 
       (make-command-packet COM_STMT_CLOSE id) 
       connection)    
    ;; No response expected 
    )
  )


;;;
;;;; Bindings for SQL abstraction layer
;;;
(define sql-connect mysql-connect)
(define sql-change-schema mysql-use-database)
(define sql-execute mysql-execute-dynamic-statement)
(define sql-execute-dynamic mysql-execute-dynamic-statement)
(define sql-prepare-statement mysql-prepare-statement)
(define sql-execute-prepared-statement mysql-execute-prepared-statement)
(define sql-close-statement mysql-close-statement)
(define sql-close-connection mysql-close-connection)

;;;
;;;; Test Case
;;;

;; Test case    
(define (test-case)             
 (with-connection (sql-connect "localhost" 3306 "test" "fred" "fred")
      ;;(mysql-execute "drop table test") 
      ;;(mysql-execute "create table test (id integer PRIMARY KEY AUTO_INCREMENT, name varchar(50), inserted datetime, amount decimal(10,2) DEFAULT -4.5)")
      (pp (sql-execute "select * from test"))
                  
      ;; Prepared Statements
      (let ((stmt1 (sql-prepare-statement "insert into test (name, amount, inserted) values (?, ?, sysdate())"))
            (stmt2 (sql-prepare-statement "select id, name, amount, inserted from test where amount > ? order by id")))
           
        (pp (sql-execute-prepared-statement stmt1 '("Fred" 10.5)))
        (pp (sql-execute-prepared-statement stmt1 '("Joe" 5.5)))
        (sql-close-statement stmt1)
        
        (pp (sql-execute-prepared-statement stmt2 '(4.5)))
        (sql-close-statement stmt2))
      
      ;; Close connection
      (sql-close-connection)))
;;(test-case)
  