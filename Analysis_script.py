import pandas as pd
import os
import numpy as np

#institutions=['lund','ki','uppsala','umea','orebro','link','gbg']
institutions=['gbg']

# Collect data
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
all_primed.to_csv('Output/All.csv')

columns=['PMID','is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year','Institution','Journal/Book']
all_no_inst=pd.DataFrame(all_primed, columns=columns)
df=all_no_inst.replace({'TRUE':True,'FALSE':False})
df.to_csv('allswedishresearch.csv')

years=[2017,2018,2019,2020,2021,2022]
transpall=df[df['Publication Year'].isin(years)]
grouped_transpall=round(transpall.groupby(['Publication Year','Institution']).mean()*100,1)
grouped_transpall.to_csv('./Output/Transparency_grouped_by_institution.csv')

years=[2017,2018,2019,2020,2021,2022]
columns=['is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year']
df_k=df.drop_duplicates(subset=['PMID'])
df_temp=pd.DataFrame(df_k, columns=columns)
df_temp=df_temp[df_temp['Publication Year'].isin(years)]
round(df_temp.groupby(['Publication Year']).mean()*100,1).to_csv('./General_transparency.csv')

years=[2017,2018,2019,2020,2021,2022]
columns=['is_coi_pred','is_register_pred','is_fund_pred','is_open_code','is_open_data','Publication Year','Institution']
df_temp=pd.DataFrame(df, columns=columns)
df_temp=df_temp[df_temp['Publication Year'].isin(years)]
round(df_temp.groupby(['Publication Year'])['Institution'].value_counts()).to_csv('./Output/Pubs_year.csv')
