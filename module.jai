// Parses the given csv string into an array of T
// The get_member function is called once for each column.
// It gets passed column title, index and get_member_data and should return the name of the member of T that the column should be parsed into.
// @ToDo: Use macro instead of get_member function?
csv_parse :: (csv_data: string, $T: Type, get_member_data: $U, get_member: (string, int, U) -> string, delimiter : u8 = #char ",", parse_integer := parse_integer_column, parse_float := parse_float_column) -> [..] T, success: bool {
	remaining_data := csv_data;
	results: [..] T;

	info := type_info(T);
	column_members: [..] *Type_Info_Struct_Member;
	defer array_free(column_members);

	last := false;
	success: bool;
	while !last {
		name: string = ---;
		name, success, last = csv_consume_col(*remaining_data, delimiter);
		if !success {
			log_error("Could not read column % of first line", column_members.count + 1);
			return results, false;
		}
		member_name := get_member(name, column_members.count, get_member_data);
		member: *Type_Info_Struct_Member;
		if member_name {
			member = get_field(info, member_name);
			if !member {
				log_error("Type % does not contain a member named \"%\"", T, member_name);
				return results, false;
			}
			tag := member.type.type;
			if tag != .STRING && tag != .INTEGER && tag != .FLOAT {
				log_error("Member \"%\" has unsupported type %", member_name, member.type);
				return results, false;
			}
		}
		array_add(*column_members, member);
	}

	while true {
		if !remaining_data	break;

		result: T;
		line_start := remaining_data;

		for column_members {
			// @Speed: Skip col if we’re not interested (instead of potentially un-quoting)
			value, success, last := csv_consume_col(*remaining_data, delimiter);
			should_be_last := (it_index == column_members.count - 1);
			if !success || last != should_be_last {
				log_error("Could not read column % of line %:\n%", it_index + 1, results.count + 2, line_start);
				return results, false;
			}
			if it {
				slot := (cast(*u8) *result) + it.offset_in_bytes;
				if it.type.type == {
					case .STRING;
						<< (cast(*string) slot) = copy_string(value);
					case .FLOAT;
						success, float_value := parse_float(it.name, value);
						if !success {
							log_error("Could not parse column % of line % as float:\n%", it_index + 1, results.count + 2, line_start);
							return results, false;
						}

						if it.type.runtime_size == 4 {
							(<< cast(*float) slot) = cast(float) float_value;
						} else {
							assert(it.type.runtime_size == 8);
							(<< cast(*float64) slot) = float_value;
						}
					case .INTEGER;
						success, int_value := parse_integer(it.name, value);
						if !success {
							log_error("Could not parse column % of line % as integer:\n%", it_index + 1, results.count + 2, line_start);
							return results, false;
						}

						int_info := cast(*Type_Info_Integer) it.type;
						success = write_integer(it.name, int_info, slot, int_value);
						if !success	then return results, false;
					case;
						// Should have been caught above
						assert(false);
				}
			}
		}
		array_add(*results, result);
	}

	return results, true;
}

csv_consume_col :: (remaining_data: *string, delimiter: u8) -> col: string, success: bool, last: bool {
	if !remaining_data.count	return "", true, true;

	num_quotes := 0;
	delim_pos := -1;
	last := false;
	for index: 0..remaining_data.count-1 {
		c := (<<remaining_data)[index];
		if c == #char "\"" {
			num_quotes += 1;
		} else if num_quotes % 2 == 0 {
			if c == delimiter {
				delim_pos = index;
				break;
			} else if c == #char "\n" {
				delim_pos = index;
				last = true;
				break;
			}
		}
	}
	col, remainder: string;
	if delim_pos == -1 {
		col = <<remaining_data;
		remaining_data.count = 0;
		last = true;
	} else {
		col = slice(<<remaining_data, 0, delim_pos);
		advance(remaining_data, delim_pos + 1);
	}

	if num_quotes == 0		return col, true, last;

	if num_quotes % 2 != 0 || col[0] != #char "\"" || col[col.count - 1] != #char "\"" {
		log_error("Invalid number of quotes: % in %", num_quotes, col);
		return "", false, last;
	}
	expected_len := col.count - num_quotes / 2;
	result := talloc_string(expected_len);
	result.count = 0;
	for index: 1..col.count-2 {
		result.data[result.count] = col[index];
		result.count += 1;
		if col[index] == #char "\""  {
			if col[index + 1] != #char "\"" {
				log_error("Invalid quote sequence at % in %", index, col);
				free(result);
				return "", false, last;
			}
			index += 1;
		}
	}
	return result, true, last;
}

// Escape a value so that it can be safely written into a CSV column. Might temporary allocate
csv_escape :: (value: string, delimiter : u8 = #char ",") -> string {
	needs_quotes := false;
	num_quotes := 0;
	for i: 0..value.count-1 {
		if value[i] == #char "\"" {
			num_quotes += 1;
			needs_quotes = true;
		} else if value[i] == #char "\n" || value[i] == delimiter {
			needs_quotes = true;
		}
	}

	if !needs_quotes	return value;

	result := talloc_string(value.count + num_quotes + 2);
	result.data[0] = #char "\"";
	result.count = 1;
	for i: 0..value.count-1 {
		result.data[result.count] = value[i];
		result.count += 1;
		if value[i] == #char "\"" {
			result.data[result.count] = #char "\"";
			result.count += 1;
		}
	}
	result.data[result.count] = #char "\"";
	result.count += 1;

	return result;
}

parse_integer_column :: (name: string, string_value: string) -> success: bool, value: s64 {
	int_value, success, remainder := to_integer(string_value);
	return success && !remainder, int_value;
}

parse_float_column :: (name: string, string_value: string) -> success: bool, value: float64 {
	float_value, success, remainder := string_to_float64(string_value);
	return success && !remainder, float_value;
}


#scope_file

// Copied from modules/Command_Line.
// @ToDo: This should probably be in modules/Reflection because all "parse into a type" parsers need it.
write_integer :: (name: string, info: *Type_Info_Integer, pointer: *void, value: s64) -> bool {
    if info.signed {
        valid, low, high := range_check_and_store(value, info, pointer);

        if !valid {
            log_error("The value of argument '%' %, which is out of range. (The value must be between % and %.)", name, value, low, high);
            return false;
        }
    } else {
        valid, low, high := range_check_and_store(cast(u64) value, info, pointer);  // Different overload from the above!

        if !valid {
            log_error("The value of argument '%' is %, which is out of range. (The value must be between % and %.)", name, cast(u64) value, low, high);
            return false;
        }
    }

    return true;
}

range_check_and_store :: (value: $T, info: *Type_Info_Integer, pointer: *void) -> (success: bool, low: T, high: T) {
    #assert((T == u64) || (T == s64));

    store :: (pointer: *void, value: T, size: int) {
        if size == {
            case 1;
                << cast(*s8)  pointer = xx,no_check value;
            case 2;
                << cast(*s16) pointer = xx,no_check value;
            case 4;
                << cast(*s32) pointer = xx,no_check value;
            case 8;
                << cast(*s64) pointer = xx,no_check value;
            case;
            assert(false);
        }
    }

    size := info.runtime_size;

    #if T == u64 {
        low, high := unsigned_integer_range_from_size(size);
        if (value < low) || (value > high)  return false, low, high;

        store(pointer, value, size);
        return true, low, high;
    } else {
        low, high := signed_integer_range_from_size(size);
        if (value < low) || (value > high)  return false, low, high;

        store(pointer, value, size);
        return true, low, high;
    }
}

signed_integer_range_from_size :: (size_in_bytes: int) -> (low: s64, high: s64) {
    assert((size_in_bytes == 1) || (size_in_bytes == 2) || (size_in_bytes == 4) || (size_in_bytes == 8));

    high := (1 << (size_in_bytes*8-1)) - 1;
    low  := ~high;

    return low, high;
}

unsigned_integer_range_from_size :: (size_in_bytes: int) -> (low: u64, high: u64) {
    assert((size_in_bytes == 1) || (size_in_bytes == 2) || (size_in_bytes == 4) || (size_in_bytes == 8));

    high: u64 = ---;
    if size_in_bytes == 8 {
        high = cast(u64) 0xffff_ffff_ffff_ffff;  // Hardcode 8 to prevent unpredictable behavior due to platform-specific details. In the future the outcome of << will be language-defined in all cases.
    } else {
        high = cast(u64) (1 << (size_in_bytes*8)) - 1;  // @CompilerBug: Why do we need to cast the 1? That is dumb.
    }

    return 0, high;
}


#import "Basic";
#import "String";
#import "Text_File_Handler";

