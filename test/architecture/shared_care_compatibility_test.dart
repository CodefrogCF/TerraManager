import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_client/shared_api_client.dart'
    as legacy_api;
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_client.dart'
    as feature_api;
import 'package:terramanager/shared_client/shared_collection_pages.dart'
    as legacy_pages;
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animals_page.dart'
    as animals;
import 'package:terramanager/shared_client/boxes/presentation/pages/shared_boxes_page.dart'
    as boxes;
import 'package:terramanager/shared_client/shared_detail_pages.dart'
    as legacy_details;
import 'package:terramanager/shared_client/animals/presentation/pages/shared_animal_detail_page.dart'
    as animal_details;
import 'package:terramanager/shared_server/care_api.dart' as legacy_care;
import 'package:terramanager/shared_server/collection/infrastructure/http/care_api.dart'
    as care;
import 'package:terramanager/shared_server/shared_server_api.dart'
    as legacy_server;
import 'package:terramanager/shared_server/app/shared_server_api.dart'
    as server;

void main() {
  test('existing Shared Care imports resolve to the same feature types', () {
    expect(legacy_api.SharedApiClient, feature_api.SharedApiClient);
    expect(legacy_api.SharedSession, feature_api.SharedSession);
    expect(legacy_api.SharedApiException, feature_api.SharedApiException);
    expect(legacy_pages.SharedAnimalsPage, animals.SharedAnimalsPage);
    expect(legacy_pages.SharedBoxesPage, boxes.SharedBoxesPage);
    expect(
      legacy_details.SharedAnimalDetailPage,
      animal_details.SharedAnimalDetailPage,
    );
    expect(legacy_care.CareApi, care.CareApi);
    expect(legacy_server.SharedServerApi, server.SharedServerApi);
  });
}
