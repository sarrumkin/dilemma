import Foundation

@MainActor
enum TaxonomyLocalization {
  static func clusterName(clusterID: Int, fallback: String) -> String {
    table.clusterByID[clusterID]?.displayName(language: AppLocalization.language) ?? fallback
  }

  static func attributeName(attributeID: Int, fallback: String) -> String {
    table.attributeByID[attributeID]?.displayName(language: AppLocalization.language)
      ?? attributeName(sourceName: fallback)
  }

  static func attributeName(sourceName: String) -> String {
    if let attribute = table.attributeBySourceName[sourceName] {
      return attribute.displayName(language: AppLocalization.language)
    }

    let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
    if let attribute = table.attributeBySourceName[trimmed] {
      return attribute.displayName(language: AppLocalization.language)
    }

    return sourceName
  }

  private static let table = TaxonomyTable.load()
}

private struct TaxonomyTable {
  let clusterByID: [Int: Cluster]
  let attributeByID: [Int: Attribute]
  let attributeBySourceName: [String: Attribute]

  static func load() -> TaxonomyTable {
    guard
      let url = Bundle.main.url(forResource: "TaxonomyLocalization", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let resource = try? JSONDecoder().decode(TaxonomyResource.self, from: data)
    else {
      return TaxonomyTable(clusters: [], attributes: [])
    }

    return TaxonomyTable(clusters: resource.clusters, attributes: resource.attributes)
  }

  init(clusters: [Cluster], attributes: [Attribute]) {
    clusterByID = Dictionary(uniqueKeysWithValues: clusters.map { ($0.id, $0) })
    attributeByID = Dictionary(uniqueKeysWithValues: attributes.map { ($0.id, $0) })

    var bySourceName: [String: Attribute] = [:]
    for attribute in attributes {
      bySourceName[attribute.source] = attribute
      bySourceName[attribute.source.trimmingCharacters(in: .whitespacesAndNewlines)] = attribute
    }
    attributeBySourceName = bySourceName
  }
}

private struct TaxonomyResource: Decodable {
  let clusters: [Cluster]
  let attributes: [Attribute]
}

private struct Cluster: Decodable {
  let id: Int
  let source: String
  let en: String
  let ru: String

  func displayName(language: AppLanguage) -> String {
    switch language {
    case .english:
      en
    case .russian:
      ru
    }
  }
}

private struct Attribute: Decodable {
  let id: Int
  let source: String
  let ru: String

  func displayName(language: AppLanguage) -> String {
    switch language {
    case .english:
      source
    case .russian:
      ru
    }
  }
}
