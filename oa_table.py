import pandas as pd
import wget

class open_access_table:
    """
    This class describes a table of open access files on Pubmed
    Central.
    """
    def __init__(self):
        self.filename = 'oa_file_list.txt'
        self.link = 'ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/' + self.filename
        self.oa_table = None
        return
    
    def get_file_list(self): 
        wget.download(self.link)
        return

    def read_file_list(self):
        colnames = ['gz_file', 'citation', 'pmcid', 'pmid', 'rights']
        self.oa_table = pd.read_csv(self.filename, sep='\t', skiprows=1, names=colnames)
        return
