import "../../../core/network/api_client.dart";
import "shelf_models.dart";

class ShelfRepository {
  ShelfRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserShelfSummary>> fetchShelves({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      "/shelves",
      accessToken: accessToken,
    );
    return response
        .map((e) => UserShelfSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<UserShelfSummary> createShelf({
    required String accessToken,
    required String name,
  }) async {
    final response = await _apiClient.postJson(
      "/shelves",
      {"name": name},
      accessToken: accessToken,
    );
    return UserShelfSummary.fromJson(response);
  }

  Future<UserShelfDetail> fetchShelf({
    required String accessToken,
    required String shelfId,
  }) async {
    final response = await _apiClient.getJson(
      "/shelves/$shelfId",
      accessToken: accessToken,
    );
    return UserShelfDetail.fromJson(response);
  }

  Future<UserShelfSummary> updateShelf({
    required String accessToken,
    required String shelfId,
    required String name,
  }) async {
    final response = await _apiClient.patchJson(
      "/shelves/$shelfId",
      {"name": name},
      accessToken: accessToken,
    );
    return UserShelfSummary.fromJson(response);
  }

  Future<void> deleteShelf({
    required String accessToken,
    required String shelfId,
  }) async {
    await _apiClient.deleteJson(
      "/shelves/$shelfId",
      accessToken: accessToken,
    );
  }

  Future<UserShelfSummary> addItemToShelf({
    required String accessToken,
    required String shelfId,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.postJson(
      "/shelves/$shelfId/items",
      {"media_item_id": mediaItemId},
      accessToken: accessToken,
    );
    return UserShelfSummary.fromJson(response);
  }

  Future<void> removeItemFromShelf({
    required String accessToken,
    required String shelfId,
    required String mediaItemId,
  }) async {
    await _apiClient.deleteJson(
      "/shelves/$shelfId/items/$mediaItemId",
      accessToken: accessToken,
    );
  }
}
