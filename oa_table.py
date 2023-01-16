from configparser import ConfigParser
import pandas as pd
import psycopg2 as ps
import wget

class open_access_table:
    """
    This class describes a table of open access files on Pubmed
    Central.
    """
    def __init__(self, table_name, config_path):
        self.table_name = table_name
        self.config_path = config_path
        self.config = self.configure()
        
        self.filename = 'oa_file_list.txt'
        self.link = 'ftp://ftp.ncbi.nlm.nih.gov/pub/pmc/' + self.filename
        self.oa_table = None
        return

    def configure(self):
        """
        Reads the .config file necessary to access the database.
        """
        # Code courtesy of https://www.postgresqltutorial.com/postgresql-python/connect/
        parser = ConfigParser()
        parser.read(self.config_path)

        config = {}
        for param in list(parser.items('database')):
            config[param[0]] = param[1]
        return config

    def get_file_list(self):
        """
        Downloads the list of open access files on Pubmed Central.
        """
        wget.download(self.link)
        return

    def read_file_list(self):
        """
        Reads a downloaded file of open access files on Pubmed Central.
        """
        colnames = ['gz_file', 'citation', 'pmcid', 'pmid', 'rights']
        raw_table = pd.read_csv(self.filename, sep='\t', skiprows=1, names=colnames, converters = {'pmcid': str, 'pmid':str})
        self.oa_table = raw_table.astype(str)
        # I am assured that this is the simultaneously 'pythonic' and 'pandorable' way of removing empty entries
        self.oa_table = self.oa_table[self.oa_table['pmid'].astype(bool)]
        return

    def execute_sql_query(self, query):
        """
        Execute some arbitrary SQL query to the database specified
        in the .config file.
        """
        # Code courtesy of https://www.postgresqltutorial.com/postgresql-python/create-tables/
        conn = ps.connect(host = self.config['host'],
                                database = self.config['database'],
                                user = self.config['user'],
                                password = self.config['password'],
                                port = self.config['port'])        
        try:
            params = self.config
            conn = ps.connect(**params)
            cur = conn.cursor()
            cur.execute(query)
            cur.close()
            conn.commit()
        except (Exception, ps.DatabaseError) as error:
            print(error)

        if conn != None:
            conn.close()
        return

    def insert_in_db_table(self):
        """
        Creates a table of pmids and pmcids
        """
        query = 'INSERT INTO {} (\n'.format(self.table_name)
        query +='pmid,\n'
        query +='pmcid\n'
        query +=')\n' 
        query +='VALUES '
        rows = []
        for pmid, pmcid in zip(self.oa_table['pmid'], self.oa_table['pmcid']):
           rows.append('({}, {})'.format(pmid.replace('PMID:', ''), pmcid.replace('PMC', '')))
        query += ',\n'.join(rows)
        query +='\nON CONFLICT (pmid) DO NOTHING;'
        self.execute_sql_query(query)
        return
