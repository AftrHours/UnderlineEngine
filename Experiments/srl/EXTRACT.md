# Semantic role extraction (SRL, ceiling test)

You label the semantic roles of the events in one chapter of a public-domain novel, for an experiment that links a later sentence to the earlier sentence it recalls by matching roles.

Input: Experiments/srl/data/<book>-chNN-sentences.json — a list of sentences: {id, paragraph, start, end, text}. Read all of them in order (the chapter text is also in Dataset/<book>/chNN.txt for context).

For EVERY sentence, list the events it states (0 to 4 role sets). A role set is:
- who (agent): the doer, as a canonical name. Resolve pronouns and descriptions to the character ("she" → "Jo", "the eldest" → "Meg", "Marmee"/"mother" → "Mrs. March"). Use exactly the same spelling for the same character everywhere in the chapter. null if none.
- did (predicate): the action as a base-form verb or short verb phrase ("give", "burn", "play piano", "want"). null if none.
- what (patient): the object or topic acted on, as a short canonical noun phrase, the same wording every time the same thing comes up ("the slippers", "Christmas money", "Beth's piano", "the letter"). null if none.
- where (location): the place, canonical ("the parlor", "the Laurence house"), null if none.

Rules:
- Canonical wording matters most: the same person, object or place must get the identical string every time in the chapter, even when the text uses a different word ("dollar"/"money", "Marmee"/"mother").
- Dialogue: the speaker's own action counts only if the line states an action ("I'll buy a book" → who Jo, did buy, what a book). Pure speech tags ("said Meg") are not events.
- Do not invent: only what the sentence states or clearly implies.

Output: write Experiments/srl/data/<book>-chNN-roles.json as a JSON list with one entry per input sentence, same order:
[{"id": 0, "roles": [{"who": "...", "did": "...", "what": "...", "where": null}]}, ...]
Use Python's json module to write it. Keep scratch files in your own folder Experiments/srl/data/work-chNN/ and touch nothing else.

Reply only with the number of sentences and role sets written.
