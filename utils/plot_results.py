import numpy as np
import matplotlib.pyplot as plt
import psycopg2
import sys

# Goals: 

#   For the given input method, display scatter plots for the following:

#   Subplot for each set of items (entries, labels, entry-label pairs, label-label pairs)
#    For each table: plot recall on the x-axis and precision on the y-axis

# i. Configure graph display parameters

# size of each point ("s")
point_size=25
# opacity of each point ("alpha") to make overlapping points evident
opacity=0.2
# Padding between subplots
padding=2.0
# Size of graph
graphsize=10
# resolution (dpi) of saved image
image_dpi=300


# i.  Process input parameter:

# outputpath fully qualified path where graph file will be saved
outputpath = str(sys.argv[1])
method = str(sys.argv[2])

# ii. Create connection to table_model database with search_path set to table_model
#     (Need to parameterise this)

tm_conn = psycopg2.connect(
    host="127.0.0.1",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# iii. Generate Plots

# Setup the figure with 4 subplots
fig, ax1 = plt.subplots(2,2,figsize=(10,10))

# Get data

# recall_<set> = recall values per table for set of entries (e), labels (l), entry-label pairs (el) or label-label pairs (ll) for given method
# precision_<set> = precision values per table for set of entries (e), labels (l), entry-label pairs (el) or label-label pairs (ll) for given method

# recall and precision for sets of entries

select_stmt="SELECT e_recall FROM entry_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
recall_entries = cur.fetchall()

select_stmt="SELECT e_precision FROM entry_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
precision_entries = cur.fetchall()

# recall and precision for sets of labels

select_stmt="SELECT l_recall FROM label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
recall_labels = cur.fetchall()

select_stmt="SELECT l_precision FROM label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
precision_labels = cur.fetchall()

# recall and precision for sets of entry-label pairs

select_stmt="SELECT el_recall FROM entry_label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
recall_el = cur.fetchall()

select_stmt="SELECT el_precision FROM entry_label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
precision_el = cur.fetchall()

# recall and precision for sets of label-label pairs

select_stmt="SELECT ll_recall FROM label_label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
recall_ll = cur.fetchall()

select_stmt="SELECT ll_precision FROM label_label_confusion WHERE table_method='"+method+"' ORDER BY table_name"
cur.execute(select_stmt)
precision_ll = cur.fetchall()

# Plot scatter graph subplot for each set of items

#    entries (Recall x-axis, precision y-axis)
ax1[0,0].scatter(recall_entries,precision_entries, s=point_size, alpha=opacity)
ax1[0,0].set_title(method+" Entries")
ax1[0,0].set_ylabel("Precision")
ax1[0,0].set_xlabel("Recall")

#    labels (Recall x-axis, precision y-axis)
ax1[0,1].scatter(recall_labels,precision_labels, s=point_size, alpha=opacity)
ax1[0,1].set_title(method+" Labels")
ax1[0,1].set_ylabel("Precision")
ax1[0,1].set_xlabel("Recall")

#    entry-label pairs (Recall x-axis, precision y-axis)
ax1[1,0].scatter(recall_el,precision_el, s=point_size, alpha=opacity)
ax1[1,0].set_title(method+" Entry-Label Pairs")
ax1[1,0].set_ylabel("Precision")
ax1[1,0].set_xlabel("Recall")

#    entry-label pairs (Recall x-axis, precision y-axis)
ax1[1,1].scatter(recall_ll,precision_ll, s=point_size, alpha=opacity)
ax1[1,1].set_title(method+" Label-Label Pairs")
ax1[1,1].set_ylabel("Precision")
ax1[1,1].set_xlabel("Recall")

# Add space between subplots
fig.tight_layout(pad=padding)

# Label the entire figure
fig.suptitle("Precision vs Recall Scatter Plot for "+method)

# Save the figure as a jpg
fig.savefig(outputpath+"/plot1_"+method+".png", dpi=image_dpi)

#plt.show()