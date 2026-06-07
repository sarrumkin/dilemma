import DecisionModels
import DiaryVault
import Foundation

extension DecisionAnalysis {
  func replacingIdentity(id: UUID, entryID: UUID, createdAt: Date) -> DecisionAnalysis {
    DecisionAnalysis(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
      model: model,
      asset: asset,
      clusterMethod: clusterMethod,
      embeddings: embeddings,
      reasonMatches: reasonMatches,
      optionAttributeProfiles: optionAttributeProfiles,
      optionClusterProfiles: optionClusterProfiles,
      metrics: metrics,
      warnings: warnings
    )
  }

  func storedModel() throws -> StoredDecisionAnalysis {
    StoredDecisionAnalysis(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
      model: model.storedModel(),
      asset: asset.storedModel(),
      clusterMethod: clusterMethod.storedModel(),
      embeddings: embeddings.storedModel(),
      reasonMatches: reasonMatches.map { $0.storedModel() },
      optionAttributeProfiles: optionAttributeProfiles.map { $0.storedModel() },
      optionClusterProfiles: optionClusterProfiles.map { $0.storedModel() },
      metrics: metrics.storedModel(),
      warnings: warnings,
      attributeConflicts: attributeConflicts.map { $0.storedModel() },
      clusterProfiles: clusterProfiles.map { $0.storedModel() }
    )
  }
}

extension StoredDecisionAnalysis {
  func decisionModel() throws -> DecisionAnalysis {
    guard hasFullAnalysisPayload else {
      return DecisionAnalysis(
        id: id,
        entryID: entryID,
        createdAt: createdAt,
        assetVersion: assetVersion,
        modelID: modelID,
        sourceDOI: sourceDOI,
        attributeConflicts: attributeConflicts.map { $0.decisionModel() },
        clusterProfiles: clusterProfiles.map { $0.decisionModel() }
      )
    }

    return DecisionAnalysis(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
      model: model.decisionModel(),
      asset: asset.decisionModel(),
      clusterMethod: clusterMethod.decisionModel(),
      embeddings: embeddings.decisionModel(),
      reasonMatches: reasonMatches.map { $0.decisionModel() },
      optionAttributeProfiles: optionAttributeProfiles.map { $0.decisionModel() },
      optionClusterProfiles: optionClusterProfiles.map { $0.decisionModel() },
      metrics: metrics.decisionModel(),
      warnings: warnings
    )
  }
}

extension AnalysisModelMetadata {
  func storedModel() -> StoredAnalysisModelMetadata {
    StoredAnalysisModelMetadata(id: id, name: name, embeddingDimension: embeddingDimension)
  }
}

extension StoredAnalysisModelMetadata {
  func decisionModel() -> AnalysisModelMetadata {
    AnalysisModelMetadata(id: id, name: name, embeddingDimension: embeddingDimension)
  }
}

extension AnalysisAssetMetadata {
  func storedModel() -> StoredAnalysisAssetMetadata {
    StoredAnalysisAssetMetadata(version: version, resourceName: resourceName, sourceDOI: sourceDOI)
  }
}

extension StoredAnalysisAssetMetadata {
  func decisionModel() -> AnalysisAssetMetadata {
    AnalysisAssetMetadata(version: version, resourceName: resourceName, sourceDOI: sourceDOI)
  }
}

extension AnalysisClusterMethodMetadata {
  func storedModel() -> StoredAnalysisClusterMethodMetadata {
    StoredAnalysisClusterMethodMetadata(id: id, label: label)
  }
}

extension StoredAnalysisClusterMethodMetadata {
  func decisionModel() -> AnalysisClusterMethodMetadata {
    AnalysisClusterMethodMetadata(id: id, label: label)
  }
}

extension AnalysisMetrics {
  func storedModel() -> StoredAnalysisMetrics {
    StoredAnalysisMetrics(
      modelLoadMilliseconds: modelLoadMilliseconds,
      embeddingMilliseconds: embeddingMilliseconds,
      scoringMilliseconds: scoringMilliseconds,
      approximateMemoryMegabytes: approximateMemoryMegabytes
    )
  }
}

extension StoredAnalysisMetrics {
  func decisionModel() -> AnalysisMetrics {
    AnalysisMetrics(
      modelLoadMilliseconds: modelLoadMilliseconds,
      embeddingMilliseconds: embeddingMilliseconds,
      scoringMilliseconds: scoringMilliseconds,
      approximateMemoryMegabytes: approximateMemoryMegabytes
    )
  }
}

extension DecisionAnalysisEmbeddings {
  func storedModel() -> StoredDecisionAnalysisEmbeddings {
    StoredDecisionAnalysisEmbeddings(
      rawText: rawText,
      dilemmaText: dilemmaText.storedModel(),
      options: options.map { $0.storedModel() },
      reasons: reasons.map { $0.storedModel() }
    )
  }
}

extension StoredDecisionAnalysisEmbeddings {
  func decisionModel() -> DecisionAnalysisEmbeddings {
    DecisionAnalysisEmbeddings(
      rawText: rawText,
      dilemmaText: dilemmaText.decisionModel(),
      options: options.map { $0.decisionModel() },
      reasons: reasons.map { $0.decisionModel() }
    )
  }
}

extension EmbeddingVector {
  func storedModel() -> StoredEmbeddingVector {
    StoredEmbeddingVector(modelID: modelID, modelName: modelName, dimension: dimension, values: values)
  }
}

extension StoredEmbeddingVector {
  func decisionModel() -> EmbeddingVector {
    EmbeddingVector(modelID: modelID, modelName: modelName, dimension: dimension, values: values)
  }
}

extension OptionEmbedding {
  func storedModel() -> StoredOptionEmbedding {
    StoredOptionEmbedding(optionIndex: optionIndex, title: title, embedding: embedding.storedModel())
  }
}

extension StoredOptionEmbedding {
  func decisionModel() -> OptionEmbedding {
    OptionEmbedding(optionIndex: optionIndex, title: title, embedding: embedding.decisionModel())
  }
}

extension ReasonEmbedding {
  func storedModel() -> StoredReasonEmbedding {
    StoredReasonEmbedding(
      reasonID: reasonID,
      optionIndex: optionIndex,
      polarity: polarity.storedModel(),
      text: text,
      embedding: embedding.storedModel()
    )
  }
}

extension StoredReasonEmbedding {
  func decisionModel() -> ReasonEmbedding {
    ReasonEmbedding(
      reasonID: reasonID,
      optionIndex: optionIndex,
      polarity: polarity.decisionPolarity(),
      text: text,
      embedding: embedding.decisionModel()
    )
  }
}

extension ReasonMatchResult {
  func storedModel() -> StoredReasonMatchResult {
    StoredReasonMatchResult(
      id: id,
      reason: reason.storedModel(),
      rawScores: rawScores,
      centeredScores: centeredScores,
      topMatches: topMatches.map { $0.storedModel() }
    )
  }
}

extension StoredReasonMatchResult {
  func decisionModel() -> ReasonMatchResult {
    ReasonMatchResult(
      id: id,
      reason: reason.decisionModel(),
      rawScores: rawScores,
      centeredScores: centeredScores,
      topMatches: topMatches.map { $0.decisionModel() }
    )
  }
}

extension ReasonInput {
  func storedModel() -> StoredReasonInput {
    StoredReasonInput(id: id, text: text, optionIndex: optionIndex, polarity: polarity.storedModel())
  }
}

extension StoredReasonInput {
  func decisionModel() -> ReasonInput {
    ReasonInput(id: id, text: text, optionIndex: optionIndex, polarity: polarity.decisionPolarity())
  }
}

extension AttributeScore {
  func storedModel() -> StoredAttributeScore {
    StoredAttributeScore(id: id, attribute: attribute.storedModel(), score: score)
  }
}

extension StoredAttributeScore {
  func decisionModel() -> AttributeScore {
    AttributeScore(id: id, attribute: attribute.decisionModel(), score: score)
  }
}

extension AttributeMetadata {
  func storedModel() -> StoredAttributeMetadata {
    StoredAttributeMetadata(
      attributeID: attributeID,
      rowIndex: rowIndex,
      name: name,
      source: source,
      direction: direction.storedModel(),
      vectorOffset: vectorOffset,
      clusterID: clusterID
    )
  }
}

extension StoredAttributeMetadata {
  func decisionModel() -> AttributeMetadata {
    AttributeMetadata(
      attributeID: attributeID,
      rowIndex: rowIndex,
      name: name,
      source: source,
      direction: direction.decisionModel(),
      vectorOffset: vectorOffset,
      clusterID: clusterID
    )
  }
}

extension OptionAttributeProfile {
  func storedModel() -> StoredOptionAttributeProfile {
    StoredOptionAttributeProfile(optionIndex: optionIndex, scores: scores.map { $0.storedModel() })
  }
}

extension StoredOptionAttributeProfile {
  func decisionModel() -> OptionAttributeProfile {
    OptionAttributeProfile(optionIndex: optionIndex, scores: scores.map { $0.decisionModel() })
  }
}

extension AttributeProfileScore {
  func storedModel() -> StoredAttributeProfileScore {
    StoredAttributeProfileScore(id: id, attribute: attribute.storedModel(), score: score)
  }
}

extension StoredAttributeProfileScore {
  func decisionModel() -> AttributeProfileScore {
    AttributeProfileScore(id: id, attribute: attribute.decisionModel(), score: score)
  }
}

extension AttributeDefinition {
  func storedModel() -> StoredAttributeDefinition {
    StoredAttributeDefinition(attributeID: attributeID, name: name, source: source, clusterID: clusterID)
  }
}

extension StoredAttributeDefinition {
  func decisionModel() -> AttributeDefinition {
    AttributeDefinition(attributeID: attributeID, name: name, source: source, clusterID: clusterID)
  }
}

extension OptionClusterProfile {
  func storedModel() -> StoredOptionClusterProfile {
    StoredOptionClusterProfile(optionIndex: optionIndex, scores: scores.map { $0.storedModel() })
  }
}

extension StoredOptionClusterProfile {
  func decisionModel() -> OptionClusterProfile {
    OptionClusterProfile(optionIndex: optionIndex, scores: scores.map { $0.decisionModel() })
  }
}

extension ClusterScore {
  func storedModel() -> StoredClusterScore {
    StoredClusterScore(id: id, cluster: cluster.storedModel(), score: score)
  }
}

extension StoredClusterScore {
  func decisionModel() -> ClusterScore {
    ClusterScore(id: id, cluster: cluster.decisionModel(), score: score)
  }
}

extension ClusterMetadata {
  func storedModel() -> StoredClusterMetadata {
    StoredClusterMetadata(
      clusterID: clusterID,
      label: label,
      representativeAttributeName: representativeAttributeName,
      sortOrder: sortOrder
    )
  }
}

extension StoredClusterMetadata {
  func decisionModel() -> ClusterMetadata {
    ClusterMetadata(
      clusterID: clusterID,
      label: label,
      representativeAttributeName: representativeAttributeName,
      sortOrder: sortOrder
    )
  }
}

extension AttributeConflict {
  func storedModel() -> StoredAttributeConflict {
    StoredAttributeConflict(
      id: id,
      attributeName: attributeName,
      option1Score: option1Score,
      option2Score: option2Score,
      difference: difference,
      rank: rank
    )
  }
}

extension StoredAttributeConflict {
  func decisionModel() -> AttributeConflict {
    AttributeConflict(
      id: id,
      attributeName: attributeName,
      option1Score: option1Score,
      option2Score: option2Score,
      difference: difference,
      rank: rank
    )
  }
}

extension ClusterProfile {
  func storedModel() -> StoredClusterProfile {
    StoredClusterProfile(
      id: id,
      optionIndex: optionIndex,
      clusterID: clusterID,
      label: label,
      score: score
    )
  }
}

extension StoredClusterProfile {
  func decisionModel() -> ClusterProfile {
    ClusterProfile(
      id: id,
      optionIndex: optionIndex,
      clusterID: clusterID,
      label: label,
      score: score
    )
  }
}

private extension ReasonPolarity {
  func storedModel() -> StoredDiaryReasonPolarity {
    StoredDiaryReasonPolarity(rawValue: rawValue) ?? .benefit
  }
}

private extension StoredDiaryReasonPolarity {
  func decisionPolarity() -> ReasonPolarity {
    ReasonPolarity(rawValue: rawValue) ?? .benefit
  }
}

private extension AttributeDirection {
  func storedModel() -> StoredAttributeDirection {
    StoredAttributeDirection(rawValue: rawValue) ?? .pro
  }
}

private extension StoredAttributeDirection {
  func decisionModel() -> AttributeDirection {
    AttributeDirection(rawValue: rawValue) ?? .pro
  }
}
