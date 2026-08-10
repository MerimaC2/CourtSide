/// Generic paged list result (mirrors the backend `PagedResult<T>`).
class SearchResult<T> {
  int count = 0;
  List<T> result = <T>[];
}
