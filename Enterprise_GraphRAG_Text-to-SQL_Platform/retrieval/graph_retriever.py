#This script help to create Graphs that include sqlDB tables as nodes and relationships as Directional edges.
import sqlite3
import networkx as nx
import json

class GraphManager:
    _graph = None
    
    @classmethod
    def get_client(graph):
        
        if graph._graph is None:
            db_path = "employee_management.db"
            con = sqlite3.connect(db_path)
            con.row_factory = sqlite3.Row
            tables = [ 
                row["name"] 
                for row in con.execute(""" 
                    SELECT name 
                    FROM sqlite_master 
                    WHERE type = 'table' 
                      AND name NOT LIKE 'sqlite_%' 
                    ORDER BY name 
                """) 
                ]
            G = nx.DiGraph()
            G.add_nodes_from(tables)

            #Creating relationship

            with open("relationship_metadata.json") as f:
                data = json.load(f)
            edge_labels = {}
            for rel in data["relationships"]:
                G.add_edge(
                    rel["from_table"],
                    rel["to_table"],
                    from_column = rel["from_column"],
                    to_column = rel["to_column"],
                    on_update = rel["on_update"],
                    on_delete = rel["on_delete"]
                )
                edge_labels[
                    (rel["from_table"], rel["to_table"])
                ] = f"{rel['from_column']} → {rel['to_column']}"

            graph._graph = G

        return graph._graph
