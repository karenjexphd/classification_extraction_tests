import numpy as np
import matplotlib.pyplot as plt
import psycopg2
import sys

# Goals: 

#   Display scatter plots for the following:

#   1. Subplot for each set of items (entries, labels, entry-label pairs, label-label pairs)
#      For each method (one colour per method) and for each table:
#      Plot recall on the x-axis and precision on the y-axis

#   2. Subplot for each set of items (entries, labels, entry-label pairs, label-label pairs)
#      For precision, recall and f-measure (one colour for each) each for table:
#      Plot TabbyXL on the x-axis and Hypoparsr on the y-axis

# i.  Process input parameter:

# outputpath fully qualified path where graph file will be saved
# outputpath = str(sys.argv[1]) 
outputpath = "/tmp"

# ii. Create connection to table_model database with search_path set to table_model
#     (Need to parameterise this)

# tm_conn = psycopg2.connect(
#     host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
#     database="table_model",
#     user="postgres")

tm_conn = psycopg2.connect(
    host="127.0.0.1",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# iii. Generate Plots

# fig1 : subplot per set of items, colour per method, dot per table, recall on x-axis, precision on y-axis
# fig2 : subplot per set of items, dot per table, colour per metric (precision, recall, f-measure), TabbyXL on x-axis, Hypoparsr on y-axis

# Setup the figures with 4 subplots
fig1, ax1 = plt.subplots(2,2)
fig2, ax2 = plt.subplots(2,2)

# Get data

# r_<set>_<method> = recall values per table for set of entries (e), labels (l), entry-label pairs (el) or label-label pairs (ll) for given method
# p_<set>_<method> = precision values per table for set of entries (e), labels (l), entry-label pairs (el) or label-label pairs (ll) for given method

# recall and precision for sets of entries

select_stmt="SELECT e_recall FROM entry_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
r_e_h = cur.fetchall()

select_stmt="SELECT e_recall FROM entry_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
r_e_t = cur.fetchall()

select_stmt="SELECT e_precision FROM entry_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
p_e_h = cur.fetchall()

select_stmt="SELECT e_precision FROM entry_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
p_e_t = cur.fetchall()

# recall and precision for sets of labels

select_stmt="SELECT l_recall FROM label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
r_l_h = cur.fetchall()

select_stmt="SELECT l_recall FROM label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
r_l_t = cur.fetchall()

select_stmt="SELECT l_precision FROM label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
p_l_h = cur.fetchall()

select_stmt="SELECT l_precision FROM label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
p_l_t = cur.fetchall()

# recall and precision for sets of entry-label pairs

select_stmt="SELECT el_recall FROM entry_label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
r_el_h = cur.fetchall()

select_stmt="SELECT el_recall FROM entry_label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
r_el_t = cur.fetchall()

select_stmt="SELECT el_precision FROM entry_label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
p_el_h = cur.fetchall()

select_stmt="SELECT el_precision FROM entry_label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
p_el_t = cur.fetchall()

# recall and precision for sets of label-label pairs

select_stmt="SELECT ll_recall FROM label_label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
r_ll_h = cur.fetchall()

select_stmt="SELECT ll_recall FROM label_label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
r_ll_t = cur.fetchall()

select_stmt="SELECT ll_precision FROM label_label_confusion WHERE table_method='hypoparsr' ORDER BY table_name"
cur.execute(select_stmt)
p_ll_h = cur.fetchall()

select_stmt="SELECT ll_precision FROM label_label_confusion WHERE table_method='tabbyxl' ORDER BY table_name"
cur.execute(select_stmt)
p_ll_t = cur.fetchall()

# Plot scatter graph subplot for each set of items

#    entries (Recall x-axis, precision y-axis)
ax1[0,0].scatter(r_e_h,p_e_h, label="Hypoparsr")
ax1[0,0].scatter(r_e_t,p_e_t, label = "TabbyXL")
ax1[0,0].legend(loc='upper left')
ax1[0,0].set_title("Entries")
ax1[0,0].set_ylabel("Precision")
ax1[0,0].set_xlabel("Recall")

#    entries (Hypoparsr x-axis, TabbyXL y-axis)
ax2[0,0].scatter(p_e_h,p_e_t, label="Precision")
ax2[0,0].scatter(r_e_h,r_e_t, label = "Recall")
ax2[0,0].legend(loc='upper left')
ax2[0,0].set_title("Entries")
ax2[0,0].set_ylabel("TabbyXL")
ax2[0,0].set_xlabel("Hypoparsr")

#    labels (Recall x-axis, precision y-axis)
ax1[0,1].scatter(r_l_h,p_l_h, label="Hypoparsr")
ax1[0,1].scatter(r_l_t,p_l_t, label = "TabbyXL")
ax1[0,1].legend(loc='upper left')
ax1[0,1].set_title("Labels")
ax1[0,1].set_ylabel("Precision")
ax1[0,1].set_xlabel("Recall")

#    labels (Hypoparsr x-axis, TabbyXL y-axis)
ax2[0,1].scatter(p_l_h,p_l_t, label="Precision")
ax2[0,1].scatter(r_l_h,r_l_t, label = "Recall")
ax2[0,1].legend(loc='upper left')
ax2[0,1].set_title("Labels")
ax2[0,1].set_ylabel("TabbyXL")
ax2[0,1].set_xlabel("Hypoparsr")

#    entry-label pairs (Recall x-axis, precision y-axis)
ax1[1,0].scatter(r_el_h,p_el_h, label="Hypoparsr")
ax1[1,0].scatter(r_el_t,p_el_t, label = "TabbyXL")
ax1[1,0].legend( loc='upper left')
ax1[1,0].set_title("Entry-Label Pairs")
ax1[1,0].set_ylabel("Precision")
ax1[1,0].set_xlabel("Recall")

#    entry-label pairs (Hypoparsr x-axis, TabbyXL y-axis)
ax2[1,0].scatter(p_el_h,p_el_t, label="Precision")
ax2[1,0].scatter(r_el_h,r_el_t, label = "Recall")
ax2[1,0].legend( loc='upper left')
ax2[1,0].set_title("Entry-Label Pairs")
ax2[1,0].set_ylabel("TabbyXL")
ax2[1,0].set_xlabel("Hypoparsr")

#    label-label pairs (Recall x-axis, precision y-axis)
ax1[1,1].scatter(r_ll_h,p_ll_h, label="Hypoparsr")
ax1[1,1].scatter(r_ll_t,p_ll_t, label = "TabbyXL")
ax1[1,1].legend(loc='upper left')
ax1[1,1].set_title("Label-Label Pairs")
ax1[1,1].set_ylabel("Precision")
ax1[1,1].set_xlabel("Recall")

#    label-label pairs (Hypoparsr x-axis, TabbyXL y-axis)
ax2[1,1].scatter(p_ll_h,p_ll_t, label="Precision")
ax2[1,1].scatter(r_ll_h,r_ll_t, label = "Recall")
ax2[1,1].legend(loc='upper left')
ax2[1,1].set_title("Label-Label Pairs")
ax2[1,1].set_ylabel("TabbyXL")
ax2[1,1].set_xlabel("Hypoparsr")

# Add space between subplots
fig1.tight_layout(pad=2.0)
fig2.tight_layout(pad=2.0)

# Label the entire figure
fig1.suptitle("Precision vs Recall Scatter Plot")
fig2.suptitle("Hypoparsr vs TabbyXL Scatter Plot")

# Save the figure as a png
fig1.savefig(outputpath+"/fig1.png", dpi=300)
fig2.savefig(outputpath+"/fig2.png", dpi=300)

plt.show()
