\echo Confusion Matrix for set of labels
SELECT * FROM label_confusion;

\echo Confusion Matrix for set of entries
SELECT * FROM entry_confusion;

\echo Confusion Matrix for set of entry-label pairs
SELECT * FROM entry_label_confusion;

\echo Confusion Matrix for set of label-label pairs
SELECT * FROM label_label_confusion;
