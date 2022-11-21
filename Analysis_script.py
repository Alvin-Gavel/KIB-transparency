"""
This script is intended to read the data output by the R script Collection_script.
"""

import os

import pandas as pd
import numpy as np

#institutions=['lund','ki','uppsala','umea','orebro','link','gbg']
institutions=['gbg']

# Combine data from the three lists we use
research = []
for ins in institutions:
  code=pd.read_csv('./Output/Codesharing/{}.csv'.format(ins))
  rest=pd.read_csv('./Output/Resttransp/{}.csv'.format(ins))
  transp=pd.merge(code, rest, on='pmid')
  transp['Institution']=ins
  transp=transp.rename(columns={'pmid':'PMID'})
  transp=transp.dropna(subset=['is_open_code','is_open_data','is_register_pred','is_coi_pred','is_fund_pred'])
  pmcoa=pd.read_csv('./Pmcoalists/{}.csv'.format(ins))
  transp=pd.merge(transp,pmcoa,on='PMID')
  transpresearch=transp[transp.is_research_x]
  research.append(transpresearch)

# Export data
all_ins=pd.concat(research)
all_ins.head()
columns=['PMID','is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year','Institution','Journal/Book']
all_primed=pd.DataFrame(all_ins, columns=columns)
all_primed=all_primed.replace({'TRUE':True,'FALSE':False})
all_primed.to_csv('Output/All.csv')

years=[2017,2018,2019,2020,2021,2022]
transpall=all_primed[all_primed['Publication Year'].isin(years)]
grouped_by_ins=round(transpall.groupby(['Publication Year','Institution']).mean()*100,1)
grouped_by_ins.to_csv('Output/Transparency_grouped_by_institution.csv')

columns=['is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year']
# I'm not sure about this one. Shouldn't we always drop duplicates?
df_temp=pd.DataFrame(all_primed.drop_duplicates(subset=['PMID']), columns=columns)
df_temp=df_temp[df_temp['Publication Year'].isin(years)]
round(df_temp.groupby(['Publication Year']).mean()*100,1).to_csv('Output/General_transparency.csv')

columns=['is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year','Institution']
df_temp=pd.DataFrame(all_primed, columns=columns)
df_temp=df_temp[df_temp['Publication Year'].isin(years)]
grouped_by_year = round(df_temp.groupby(['Publication Year'])['Institution'].value_counts())
grouped_by_year.to_csv('Output/Pubs_year.csv')
