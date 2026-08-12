-- RX Flooring — test assessment requests for manager UI design
-- Run in Supabase SQL Editor (bypasses RLS):
-- https://supabase.com/dashboard/project/xddnrxxlkwlpowieufjf/sql/new
--
-- Safe to re-run: deletes prior rows with phone prefix 613-555-9xxx first.

delete from public.assessment_requests
where phone like '613-555-9%';

insert into public.assessment_requests (
  name, phone, address, preferred_date, preferred_window, notes, services, status
) values
  (
    'Sarah Chen',
    '613-555-9101',
    '42 Maple Ridge Dr, Kanata',
    (current_date + interval '1 day')::date,
    'Morning (8–12)',
    'Living room + hallway. Old carpet peeling at seams.',
    array['Carpet', 'Removal'],
    'new'
  ),
  (
    'Marcus Okonkwo',
    '613-555-9102',
    '1185 Bank Street, Ottawa',
    current_date,
    'Afternoon (12–4)',
    'Basement LVP bubbling near laundry.',
    array['LVP', 'Subfloor'],
    'scheduled'
  ),
  (
    'Priya Nair',
    '613-555-9103',
    'Orleans — Fallingbrook',
    (current_date + interval '5 days')::date,
    'Late afternoon (4–6)',
    null,
    array['Stairs', 'Carpet'],
    'contacted'
  ),
  (
    'James & Lori Tremblay',
    '613-555-9104',
    '88 Riverside Cres, Manotick',
    (current_date - interval '1 day')::date,
    'Morning (8–12)',
    'Main floor hardwood. Two dogs — pet-friendly finish.',
    array['Hardwood', 'Refinish'],
    'done'
  ),
  (
    'Alex Rivera',
    '613-555-9105',
    'Nepean',
    (current_date - interval '12 days')::date,
    'Afternoon (12–4)',
    'Went with another contractor.',
    array['Tile'],
    'closed'
  ),
  (
    'Emily Watson',
    '613-555-9106',
    '15 Elgin St, Ottawa',
    current_date,
    'Morning (8–12)',
    'Urgent — move-in next Friday.',
    array['Carpet', 'Stairs'],
    'new'
  ),
  (
    'David Kowalski',
    '613-555-9107',
    'Stittsville',
    (current_date - interval '30 days')::date,
    'Late afternoon (4–6)',
    'Old row for archived filter.',
    array['Laminate'],
    'archived'
  ),
  (
    'No Services Nguyen',
    '613-555-9108',
    'Barrhaven',
    (current_date + interval '2 days')::date,
    'Afternoon (12–4)',
    'Customer did not pick services on the form.',
    '{}',
    'new'
  ),
  (
    'Long Notes Patterson',
    '613-555-9109',
    'Westboro — Richmond Road area',
    (current_date + interval '3 days')::date,
    'Morning (8–12)',
    'Hall carpet is rippling. Stair runner wanted in charcoal. Previous install was DIY. Please call before 9am — works night shifts. Also interested in quote for basement if main floor goes well.',
    array['Carpet', 'Stairs', 'Removal'],
    'contacted'
  );
