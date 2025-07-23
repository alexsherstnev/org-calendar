__version__ = "0.1.0"

import argparse
import datetime
from pathlib import Path

import arrow
import icalendar
import recurring_ical_events
import requests


def parse_args():
    parser = argparse.ArgumentParser(description="Convert iCal to org-mode for agenda.")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s v{__version__} © 2025 by Aliaksandr Sharstniou",
        help="Show version and exit",
    )
    parser.add_argument(
        "--url",
        required=True,
        help="URL of the .ics file",
    )
    parser.add_argument(
        "--output",
        default="calendar.org",
        help="Output org-mode file (default: calendar.org)",
    )
    parser.add_argument(
        "--weeks",
        type=int,
        default=2,
        help="Number of weeks to fetch (default: 2)",
    )
    parser.add_argument(
        "--tags",
        default=":work:",
        help="Org-mode tags for events (default: :work:)",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    # Load calendar
    try:
        calendar = icalendar.Calendar.from_ical(requests.get(args.url).text)
    except Exception as e:
        raise SystemExit(f"Error loading calendar: {e}")

    # Date range (current week + N weeks ahead)
    begin_date = arrow.now().floor("week")
    end_date = begin_date.shift(weeks=+args.weeks)

    # Get events
    events = recurring_ical_events.of(calendar).between(
        begin_date.date(), end_date.date()
    )
    local_tz = datetime.datetime.now().astimezone().tzinfo

    # Prepare org-mode content
    org_content = []
    for event in events:
        start = event["DTSTART"].dt
        end = event["DTEND"].dt
        summary = event["SUMMARY"]

        # Timezone conversion
        if isinstance(start, datetime.datetime):
            start = start.astimezone(local_tz)
        if isinstance(end, datetime.datetime):
            end = end.astimezone(local_tz)

        # Format time range
        if isinstance(start, datetime.datetime) and isinstance(end, datetime.datetime):
            org_time = f"<{start.strftime('%Y-%m-%d %H:%M')}-{end.strftime('%H:%M')}>"
        else:
            org_time = f"<{start.strftime('%Y-%m-%d')}>"  # All-day event

        # Build org entry
        org_content.append(f"* {summary} {args.tags}")
        org_content.append(f"SCHEDULED: {org_time}")
        org_content.append("")  # Empty line between events

    # Write to file
    Path(args.output).write_text("\n".join(org_content))
    print(f"Saved {len(events)} events to {args.output}")


if __name__ == "__main__":
    main()
