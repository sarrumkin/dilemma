# Similarity Methods Swift Evaluation

- Model: sentence-transformers/all-MiniLM-L12-v2
- Dataset: synthetic English dilemmas
- Top K: 3
- Evaluation: qualitative illustrative retrieval, not a statistical benchmark

## Hit Summary

| Method | hits@3 | Queries |
| --- | ---: | ---: |
| Bhatia clusters | 4 | 4 |
| KMeans clusters | 4 | 4 |
| Full-text embedding | 4 | 4 |

## query-career-home

- Label: career_family_balance
- Relevant records: career-family-remote, career-family-startup

| Method | Rank | Record | Score | Relevant |
| --- | ---: | --- | ---: | --- |
| Bhatia clusters | 1 | career-family-remote | 0.9539 | yes |
| Bhatia clusters | 2 | comfort-learning-language | 0.9122 | no |
| Bhatia clusters | 3 | career-family-startup | 0.9050 | yes |
| KMeans clusters | 1 | career-family-remote | 0.9610 | yes |
| KMeans clusters | 2 | comfort-learning-language | 0.9070 | no |
| KMeans clusters | 3 | health-work-overtime | 0.8978 | no |
| Full-text embedding | 1 | career-family-remote | 0.5090 | yes |
| Full-text embedding | 2 | career-family-startup | 0.4800 | yes |
| Full-text embedding | 3 | health-work-rest | 0.4158 | no |

## query-family-savings

- Label: money_family_support
- Relevant records: money-family-parent, money-family-support

| Method | Rank | Record | Score | Relevant |
| --- | ---: | --- | ---: | --- |
| Bhatia clusters | 1 | money-family-support | 0.9525 | yes |
| Bhatia clusters | 2 | money-family-parent | 0.9258 | yes |
| Bhatia clusters | 3 | similar-words-career-no-family | 0.8672 | no |
| KMeans clusters | 1 | money-family-support | 0.9544 | yes |
| KMeans clusters | 2 | money-family-parent | 0.9042 | yes |
| KMeans clusters | 3 | security-adventure-travel | 0.8572 | no |
| Full-text embedding | 1 | money-family-support | 0.7370 | yes |
| Full-text embedding | 2 | money-family-parent | 0.5525 | yes |
| Full-text embedding | 3 | career-family-remote | 0.3341 | no |

## query-rest-deadline

- Label: health_work_boundary
- Relevant records: health-work-overtime, health-work-rest

| Method | Rank | Record | Score | Relevant |
| --- | ---: | --- | ---: | --- |
| Bhatia clusters | 1 | health-work-rest | 0.9833 | yes |
| Bhatia clusters | 2 | health-work-overtime | 0.9609 | yes |
| Bhatia clusters | 3 | comfort-fitness-training | 0.9062 | no |
| KMeans clusters | 1 | health-work-rest | 0.9771 | yes |
| KMeans clusters | 2 | health-work-overtime | 0.9580 | yes |
| KMeans clusters | 3 | comfort-fitness-training | 0.8823 | no |
| Full-text embedding | 1 | health-work-overtime | 0.6075 | yes |
| Full-text embedding | 2 | health-work-rest | 0.5412 | yes |
| Full-text embedding | 3 | comfort-learning-language | 0.4919 | no |

## query-discipline-comfort

- Label: comfort_growth_goal
- Relevant records: comfort-fitness-training, comfort-learning-language

| Method | Rank | Record | Score | Relevant |
| --- | ---: | --- | ---: | --- |
| Bhatia clusters | 1 | comfort-learning-language | 0.9727 | yes |
| Bhatia clusters | 2 | comfort-fitness-training | 0.9025 | yes |
| Bhatia clusters | 3 | career-family-startup | 0.8902 | no |
| KMeans clusters | 1 | comfort-learning-language | 0.9705 | yes |
| KMeans clusters | 2 | comfort-fitness-training | 0.8708 | yes |
| KMeans clusters | 3 | career-family-startup | 0.8520 | no |
| Full-text embedding | 1 | comfort-learning-language | 0.5484 | yes |
| Full-text embedding | 2 | comfort-fitness-training | 0.4869 | yes |
| Full-text embedding | 3 | health-work-overtime | 0.4400 | no |

## Notes

- Bhatia and KMeans methods compare conflict structure over the same 207 Bhatia attributes.
- Bhatia uses the reconstructed Ward mapping from Reddit option profiles.
- KMeans uses an alternate grouping of the same attributes by MiniLM L12 mean pro/con embeddings.
- Full-text embedding compares canonical structured text directly.
