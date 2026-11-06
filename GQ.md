# Guiding Questions

Guiding questions for the ML Institute, Challenge 7.

iRead is a reading app that underlines phrases in a novel and links each one to the earlier sentence that explains it, without spoilers. We're working on on-device NLP with Apple Foundation Models, using prompt engineering and evaluators to measure each change.

## Prompt Engineering

- What makes a prompt clear for a small on-device model compared to a larger cloud model?
- How much context should we include in a prompt? Can too much context make results worse?
- Does the order of the options we give the model affect which one it picks?
- How should we version and document our prompts as they change?
- Is a change in prompt wording enough to compare two versions, or do we need to run them several times?
- How do we test one prompt change at a time without losing track of what helped?

## Foundation Models

- What is the best way to work with the context size limit when the source text is very long?
- When should we use guided generation, and when is free text better?
- How does the way we design a structured output affect the quality of the answer?
- Should we create a new session for each request or keep one session going?
- How do temperature and sampling settings affect results, and which should we use for evaluation?
- How can we make results as consistent as possible between runs?
- How do we balance quality, speed, and battery use on-device?

## Retrieval and NLP

- How do we choose between embeddings, keyword matching, or both for finding relevant text?
- How do we choose how many candidates to send to the model?
- How do we know whether a wrong result came from the retrieval step or the model?
- Are built-in embeddings good enough for literary or older English?
- How should we split long text into pieces for retrieval?
- How do we choose thresholds and weights without just guessing?

## Evaluators and Metrics

- Which metrics should we look at first when we are just starting?
- How do we measure quality for a task that has more than one acceptable answer?
- What is the difference between a rule-based evaluator and an LLM judge, and when should we use each?
- How do we balance precision and recall when a wrong answer hurts more than a missing one?
- How do we evaluate each pipeline step separately as well as the whole system?
- How do we read an evaluation result when overall scores go up but some cases get worse?
- What score is good enough to ship a feature?
- How can we use evaluation failures to decide what to improve next?

## Golden Set

- How many examples do we need for a useful golden set at the start?
- How do we write clear labeling guidelines for a subjective task?
- Should a golden set include cases where the correct answer is "nothing"?
- How do we avoid overfitting our prompts to the golden set?
- Can we use AI to help create a golden set, and what are the risks?
- How do we make sure results from one book or chapter apply to other books?
