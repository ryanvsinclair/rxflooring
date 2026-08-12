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
    completed_at: form.completed_at || null,
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

function todayInputValue(now) {
  var d = now || new Date();
  var m = String(d.getMonth() + 1).padStart(2, "0");
  var day = String(d.getDate()).padStart(2, "0");
  return d.getFullYear() + "-" + m + "-" + day;
}

function completedAtIso(dateStr) {
  if (!dateStr) return null;
  return new Date(dateStr + "T12:00:00").toISOString();
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
var today = todayInputValue(new Date("2026-08-12T15:00:00"));
var p1 = draftPayloadFromForm(
  { title: "", description: "", address: "", notes: "", completed_at: completedAtIso(today), assessmentId: null },
  null,
  []
);
assert(p1.title === "Untitled draft", "new draft title");
assert(p1.published === false && p1.status === "planned", "new draft flags");
assert(p1.prescribed === null, "no services → null prescribed");
assert(typeof p1.completed_at === "string" && p1.completed_at.indexOf("2026-08-12") === 0, "today date saved");

// Selected services become prescribed text
var p2 = draftPayloadFromForm(
  { title: "Living room", description: "x", address: "", notes: "", completed_at: completedAtIso("2026-08-01"), assessmentId: null },
  { status: "complete", published: true },
  ["Carpet Installation", "LVP / LVT Installation"]
);
assert(p2.published === true && p2.status === "complete", "live edit preserves publish");
assert(p2.prescribed === "Carpet Installation · LVP / LVT Installation", "prescribed from picks");
assert(typeof p2.completed_at === "string" && p2.completed_at.indexOf("2026-08-01") === 0, "changed date kept");

// Edit archived stays archived
var p3 = draftPayloadFromForm(
  { title: "Old job", description: "", address: "", notes: "", completed_at: null, assessmentId: null },
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

assert(todayInputValue(new Date("2026-08-12T08:00:00")) === "2026-08-12", "today input value");

console.log("OK — draft payload + date + services pick logic (12 checks)");
