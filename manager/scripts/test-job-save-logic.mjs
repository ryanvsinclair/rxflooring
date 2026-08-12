#!/usr/bin/env node
/**
 * Unit checks for manager job draft save rules (no Supabase auth required).
 * Run: node manager/scripts/test-job-save-logic.mjs
 */

function draftPayloadFromForm(form, existing, selectedTitles) {
  var title = form.title.trim() || "Untitled draft";
  var prescribed = (selectedTitles || []).filter(Boolean).join(" · ") || null;
  var payload = {
    title: title,
    description: form.description.trim() || null,
    prescribed: prescribed,
    address: form.address.trim() || null,
    notes: form.notes.trim() || null,
  };
  if (existing) {
    payload.status = existing.status;
    payload.published = !!existing.published;
  } else {
    payload.status = "planned";
    payload.published = false;
  }
  if (form.assessmentId) payload.assessment_request_id = form.assessmentId;
  return payload;
}

function jobBucketOf(job) {
  if (job.status === "archived") return "archived";
  if (job.published) return "live";
  return "draft";
}

function matchServiceTitles(catalog, titles) {
  var want = {};
  (titles || []).forEach(function (t) {
    var key = String(t || "").trim().toLowerCase();
    if (key) want[key] = true;
  });
  return catalog.filter(function (s) {
    return want[String(s.title || "").toLowerCase()] || want[String(s.slug || "").toLowerCase()];
  }).map(function (s) { return s.id; });
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

// New draft
var p1 = draftPayloadFromForm(
  { title: "", description: "", address: "", notes: "", assessmentId: null },
  null,
  []
);
assert(p1.title === "Untitled draft", "new draft title");
assert(p1.published === false && p1.status === "planned", "new draft flags");
assert(p1.prescribed === null, "no services → null prescribed");

// Selected services become prescribed text
var p2 = draftPayloadFromForm(
  { title: "Living room", description: "x", address: "", notes: "", assessmentId: null },
  { status: "complete", published: true },
  ["Carpet Installation", "LVP / LVT Installation"]
);
assert(p2.published === true && p2.status === "complete", "live edit preserves publish");
assert(p2.prescribed === "Carpet Installation · LVP / LVT Installation", "prescribed from picks");

// Edit archived stays archived
var p3 = draftPayloadFromForm(
  { title: "Old job", description: "", address: "", notes: "", assessmentId: null },
  { status: "archived", published: false },
  []
);
assert(p3.status === "archived", "archived edit preserved");

// Buckets
assert(jobBucketOf({ status: "planned", published: false }) === "draft", "draft bucket");
assert(jobBucketOf({ status: "complete", published: true }) === "live", "live bucket");
assert(jobBucketOf({ status: "archived", published: false }) === "archived", "archived bucket");

// Assessment title match
var catalog = [
  { id: "1", slug: "carpet", title: "Carpet Installation" },
  { id: "2", slug: "lvp", title: "LVP / LVT Installation" },
  { id: "3", slug: "removal", title: "Flooring Removal & Disposal" }
];
var ids = matchServiceTitles(catalog, ["Carpet Installation", "lvp"]);
assert(ids.join(",") === "1,2", "match by title and slug");

console.log("OK — draft payload + services pick logic (9 checks)");
