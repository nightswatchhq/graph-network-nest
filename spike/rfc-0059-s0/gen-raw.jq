# Input: schema.json. $m[0]: segments/manifest.json.
# Physical types per docs/reading-segments.md: four UInt64 names, everything else Utf8.
def coltype: if . == "block_number" or . == "log_index" or . == "_seq" or . == "block_timestamp"
             then "UBIGINT" else "VARCHAR" end;
($m[0].tables) as $cat
| .tables[] | .table as $t
| ([.columns[].name | "CAST(NULL AS \(coltype)) AS \"\(.)\""] | join(", ")) as $empty
| (($cat[$t] // []) | map(select(.to_block > $lo and .from_block <= $hi))
   | map("'" + $dir + "/" + .file + "'")) as $hit
| if ($hit | length) > 0 then
    "CREATE OR REPLACE VIEW \"\($t)\" AS SELECT * FROM (SELECT \($empty) WHERE false) UNION ALL BY NAME SELECT * FROM read_parquet([\($hit | join(","))], union_by_name = true) WHERE block_number > \($lo) AND block_number <= \($hi);"
  else
    "CREATE OR REPLACE VIEW \"\($t)\" AS SELECT \($empty) WHERE false;"
  end
