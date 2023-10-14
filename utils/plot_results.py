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

# Specify range 0 to 1 for the x and y axes of all plots

plt.xlim(0, 1)
plt.ylim(0, 1)

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

# Set shared properties for the subplots

for a in (0,1):
  for b in (0,1):
    ax1[a,b].set_xlim([0,1])
    ax1[a,b].set_ylim([0,1])
    ax1[a,b].set_ylabel("Precision")
    ax1[a,b].set_xlabel("Recall")

# Plot scatter graph subplot for each set of items

#    entries (top left subplot)
x=recall_entries
y=precision_entries
ax1[0,0].scatter(x,y, s=point_size, alpha=opacity)
ax1[0,0].set_title(method+" Entries")

#    labels (top right subplot)
x=recall_labels
y=precision_labels
ax1[0,1].scatter(x,y, s=point_size, alpha=opacity)
ax1[0,1].set_title(method+" Labels")

#    entry-label pairs (bottom left subplot)
x=recall_el
y=precision_el
ax1[1,0].scatter(x,y, s=point_size, alpha=opacity)
ax1[1,0].set_title(method+" Entry-Label Pairs")

#    entry-label pairs (bottom right subplot)
x=recall_ll
y=precision_ll
ax1[1,1].scatter(x,y, s=point_size, alpha=opacity)
ax1[1,1].set_title(method+" Label-Label Pairs")


# Add space between subplots
fig.tight_layout(pad=padding)

# Label the entire figure
fig.suptitle("Precision vs Recall Scatter Plot for "+method)

# Save the figure as a jpg
fig.savefig(outputpath+"/plot1_"+method+".png", dpi=image_dpi)

#plt.show()

