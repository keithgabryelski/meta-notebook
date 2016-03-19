#!/bin/bash

psql < create_db.sql
psql -d meta_notes < db.sql
#psql -d meta_notes < data.sql
