#!/usr/bin/env node
/**
 * Unit checks for manager job draft save rules (no Supabase auth required).
 * Run: node manager/scripts/test-job-save-logic.mjs
 */

function draftPayloadFromForm(form, existing) {
  var title = form.title.trim() || "Untitled draft";
  var payload = {
    title: title,
    description: form.description.trim() || null,
    prescribed: form.prescribed.trim() || null,
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

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

// New draft
var p1 = draftPayloadFromForm(
  { title: "", description: "", prescribed: "", address: "", notes: "", assessmentId: null },
  null
);
assert(p1.title === "Untitled draft", "new draft title");
assert(p1.published === false && p1.status === "planned", "new draft flags");

// Edit live job must not unpublish
var p2 = draftPayloadFromForm(
  { title: "Living room", description: "x", prescribed: "Carpet", address: "", notes: "", assessmentId: null },
  { status: "complete", published: true }
);
assert(p2.published === true && p2.status === "complete", "live edit preserves publish");

// Edit archived stays archived
var p3 = draftPayloadFromForm(
  { title: "Old job", description: "", prescribed: "", address: "", notes: "", assessmentId: null },
  { status: "archived", published: false }
);
assert(p3.status === "archived", "archived edit preserved");

// Buckets
assert(jobBucketOf({ status: "planned", published: false }) === "draft", "draft bucket");
assert(jobBucketOf({ status: "complete", published: true }) === "live", "live bucket");
assert(jobBucketOf({ status: "archived", published: false }) === "archived", "archived bucket");

console.log("OK — draft payload + bucket logic (6 checks)");
