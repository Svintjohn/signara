# Deaf review checklist (what to ask a Deaf reviewer)

Run this as a paid or properly credited consultation where possible, not a favor.
Record answers in `assets/vocab/vocab_v0.json` (add a `"reviewed": "name/date"`
field) and in the thesis. Anything not reviewed stays labeled DRAFT in the app.

1. **Vocab (`assets/vocab/vocab_v0.json`):** for each sign: Is the gloss right? Is the
   sign commonly used, or regional/old/outdated? Is a better sign used in the
   Philippines? Is the reference animation shape right?
2. **Emergency phrases** (`lib/data/emergency_phrases.dart`): is the wording natural?
   Is "Deaf po ako" appropriate? What would you want a hearing responder to read?
3. **Culture section** (`lib/features/culture/culture_screen.dart`): anything wrong,
   outdated, patronizing, or missing? Capital-D Deaf vs deaf wording OK?
4. **Product:** would you use this? What is dangerous about it (people trusting a
   wrong translation in an emergency)? What would you never want it to do?
5. **ASL vs FSL:** what would a useful FSL version need first?
6. **Credit and payment:** how do you want to be credited, if at all?
