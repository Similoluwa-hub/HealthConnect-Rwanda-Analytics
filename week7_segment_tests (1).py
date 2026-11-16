"""
Week 7 evidence: do the Week 6 findings hold up across segments?
Run:  python week7_segment_tests.py
Needs: pip install pandas scipy sqlalchemy psycopg2-binary
Set the connection below. Uses the views from healthconnect_queries.sql (A4 to A7).
"""
import pandas as pd, numpy as np
from scipy import stats
from sqlalchemy import create_engine
HOST,PORT,DB,USER,PASSWORD="localhost",5432,"healthconnect_rwanda","postgres","YOUR_PASSWORD_HERE"
eng=create_engine(f"postgresql+psycopg2://{USER}:{PASSWORD}@{HOST}:{PORT}/{DB}")
q=lambda s:pd.read_sql(s,eng)
a=q("select facilityid,appt_date,departmentname,visittype,provincename from v_appointment")
a["month"]=pd.to_datetime(a.appt_date).dt.month
rows=[]
def add(finding,test,p,verdict,detail=""): rows.append([finding,test,round(float(p),3),verdict,detail])
def v(p): return "Not significant" if p>0.05 else "Significant"
f=a.facilityid.value_counts().sort_index()
p=stats.chisquare(f.values).pvalue; add("Facility workload differs","Chi-square, equal share",p,v(p),f"range {f.min()} to {f.max()}")
t=a.assign(h=np.where(a.month<=6,"H1","H2")).groupby(["facilityid","h"]).size().unstack()
r=stats.spearmanr(t.H1,t.H2); add("Facility ranking is stable","H1 vs H2 rank correlation",r.pvalue,"Unstable" if r.pvalue>0.05 else "Stable",f"correlation {r.statistic:.2f}")
d=a.departmentname.value_counts(); p=stats.chisquare(d.values).pvalue; add("Department workload differs","Chi-square",p,v(p),f"range {d.min()} to {d.max()}")
p=stats.chisquare(a.visittype.value_counts().values).pvalue; add("Visit type mix","Chi-square",p,v(p))
w=pd.to_datetime(a.appt_date).dt.dayofweek.value_counts(); p=stats.chisquare(w.values).pvalue; add("Weekday pattern","Chi-square",p,v(p))
m=a.month.value_counts(); p=stats.chisquare(m.values).pvalue; add("Monthly pattern","Chi-square",p,v(p),f"range {m.min()} to {m.max()}")
p=stats.chi2_contingency(pd.crosstab(a.provincename,a.visittype))[1]; add("Emergency share by province","Province x visit type",p,v(p))
fb=q("select v.facilityid,v.departmentname,v.provincename,f.rating from patient_feedback f join v_appointment v using(appointmentid)")
for col,name in [("facilityid","facility"),("departmentname","department"),("provincename","province")]:
    p=stats.f_oneway(*[x.rating.values for _,x in fb.groupby(col)]).pvalue; add(f"Satisfaction differs by {name}","One-way ANOVA",p,v(p),f"{len(fb)} linked ratings")
pt=q("select provincename,has_chronic from v_patient")
n=pt.provincename.value_counts(); p=stats.chisquare(n.values).pvalue; add("Patients differ by province","Chi-square",p,v(p))
p=stats.chi2_contingency(pd.crosstab(pt.provincename,pt.has_chronic))[1]; add("Chronic rate differs by province","Chi-square",p,"Borderline" if p<0.05 else v(p),"one of many tests; may be chance")
out=pd.DataFrame(rows,columns=["Finding tested","Test","p-value","Verdict","Detail"])
print(out.to_string(index=False)); out.to_csv("segment_test_results.csv",index=False)
