module main

import strings

fn fuzzy_find(query string, items []string) ?FuzzyResult {
	mut results := []FuzzyResult{}
	for item in items {
		score := fuzzy_score(query, item)
		if score > 0 {
			results << FuzzyResult{
				score: score
				index: items.index(item)
			}
		}
	}
	if results.len == 0 {
		return none
	}

	results.sort_with_compare(fn (a &FuzzyResult, b &FuzzyResult) int {
		return b.score - a.score
	})

	return results[0]
}

fn fuzzy_score(query string, item string) int {
	mut score := 0

	if item.starts_with(query) {
		score += 10
	}
	mut index := 0
	for ch in query {
		pos := item.index_after(ch.ascii_str(), index)
		if pos == none {
			break
		} else {
			score += 3
			bonus := 5 - (pos - index)
			if bonus > 0 {
				score += bonus
			}
			index = pos + 1
		}
	}

	score += int(strings.levenshtein_distance_percentage(item, query) * 0.05)
	return score
}

struct FuzzyResult {
	score int
	index int
}
