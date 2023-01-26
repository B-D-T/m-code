// fnTableEnsureColExists

// Checks that the column exists in the table.
// If it doesn't, it creates that column and fills it with a specified valued (e.g., "n/a")

(input_table as table, col_name as text, optional fill_value) as table =>
    let
        fill_val = if fill_value is null then "n/a" else fill_value,
        col_in_table = List.Contains(Table.ColumnNames(input_table), col_name)
    in if not col_in_table
        then Table.AddColumn(input_table, col_name, each "n/a")
        else input_table
