# Chat Export Feature

## Overview
The Chat Export feature allows any member of an ended operation to export the full chat transcript as a PDF report, along with all media files (photos and videos) downloaded locally to their device.

## Feature Specifications

### Availability
- ✅ Only visible when operation `state == .ended`
- ✅ Available to **all members** (not just Case Agent)
- ✅ Accessed from the **Operation Details** screen

### Export Contents
1. **PDF Report** (`Chat_Export_[OperationName]_[timestamp].pdf`)
   - Cover page with operation metadata
   - Incident number, dates, participant list
   - Filters applied (if any)
   - Full chat transcript with:
     - Timestamp and user name for each message
     - Message content
     - Media thumbnails (100x100px) for photos
     - Video placeholders with 📹 icon
     - Filename for each media item

2. **Media Folder** (`Chat_Media_[OperationName]_[timestamp]/`)
   - Full-resolution photos
   - Video files
   - Original filenames preserved

### Filtering Options
Users can filter the export by:

1. **Date/Time Range**
   - From: [Date & Time]
   - To: [Date & Time]
   - Default: Full operation duration

2. **Members**
   - Multi-select from operation members
   - Default: All members included

## Implementation

### Files Created

#### 1. `Services/ChatExportService.swift`
Core export service that handles:
- Fetching messages from database
- Downloading media from Supabase Storage
- Generating PDF using PDFKit
- Organizing media files in a folder

**Key Methods:**
```swift
func exportChat(
    operationId: UUID,
    operation: Operation,
    members: [User],
    filters: ChatExportFilters = ChatExportFilters()
) async throws -> ChatExportResult
```

#### 2. `Views/ChatExportFilterView.swift`
SwiftUI view for filter selection:
- Date/time pickers
- Member selection with checkboxes
- Export preview information
- Validation (e.g., at least one member must be selected)

#### 3. Updated `Views/ActiveOperationDetailView.swift`
- Added "Export Chat Report" button (only visible for ended operations)
- Sheet presentation for filter view
- Export progress indicator
- Error handling and display
- iOS share sheet integration

### Data Flow

```
User taps "Export Chat Report"
    ↓
ChatExportFilterView presented
    ↓
User selects filters (optional)
    ↓
User taps "Export"
    ↓
ChatExportService.exportChat() called
    ↓
1. Fetch all messages from database
2. Apply filters
3. Download media files
4. Generate PDF with PDFKit
5. Organize media in folder
    ↓
iOS Share Sheet presented
    ↓
User selects destination:
- Save to Files
- AirDrop
- Email
- Other apps
```

### Database Query

Messages are fetched with a JOIN to get user names:

```swift
.from("op_messages")
.select("*, users!sender_user_id(full_name)")
.eq("operation_id", value: operationId.uuidString)
.order("created_at", ascending: true)
```

### PDF Generation

Using `UIGraphicsPDFRenderer`:
- **Page Size**: 612 x 792 points (US Letter)
- **Margins**: 50 points
- **Cover Page**: Operation details and metadata
- **Message Pages**: Chronological transcript with media thumbnails
- **Pagination**: Automatic page breaks for long conversations

### Media Handling

**Photos:**
- Thumbnail in PDF: 100x100px
- Full resolution saved to media folder
- Format preserved (JPEG/PNG)

**Videos:**
- Placeholder in PDF: 100x100px gray box with 📹 icon
- Full video saved to media folder
- Format preserved (MP4/MOV)

## UI Components

### Export Button
- **Location**: Operation Details screen, after "Save as Template"
- **Appearance**: 
  - Green background (opacity 0.1)
  - Green text
  - Icon: `square.and.arrow.up`
  - Full-width button
- **States**:
  - Normal: Tappable
  - Exporting: Disabled with progress indicator
  - Error: Red error message displayed

### Filter View
- **Navigation Title**: "Export Chat"
- **Sections**:
  1. Operation Details (read-only summary)
  2. Time Range (toggle + date pickers)
  3. Members (toggle + checkboxes)
  4. Export Contents (preview information)
- **Validation**: Prevents export if member filter is on but none selected

## Error Handling

### Possible Errors
1. **No messages to export** (with filters applied)
   - User-friendly message: "No messages to export with the selected filters"
   
2. **Media download failure**
   - Continues with other media
   - Logs error but doesn't fail entire export
   
3. **PDF generation failure**
   - Error message displayed in UI
   
4. **No network connection**
   - Standard error handling

## Performance Considerations

### Optimization Strategies
1. **Parallel Media Downloads**
   - Downloads media files sequentially (to avoid memory spikes)
   - Could be optimized to download 3-5 in parallel if needed

2. **Memory Management**
   - Media stored temporarily in-memory during export
   - Cleaned up after export completes
   - PDF written directly to temporary directory

3. **Progress Indication**
   - Shows "Generating export..." during process
   - Could be enhanced with percentage progress

## Testing Checklist

### Manual Testing
- [ ] Button only visible on ended operations
- [ ] Button hidden on active/draft operations
- [ ] Filter view presents correctly
- [ ] Date range pickers work correctly
- [ ] Member selection toggles work
- [ ] Export validation works (member filter)
- [ ] PDF generation succeeds with no media
- [ ] PDF generation succeeds with photos only
- [ ] PDF generation succeeds with videos only
- [ ] PDF generation succeeds with mixed media
- [ ] Media folder contains all files
- [ ] Share sheet presents correctly
- [ ] Save to Files works
- [ ] AirDrop works
- [ ] Email attachment works
- [ ] Export with date filter works
- [ ] Export with member filter works
- [ ] Export with no filters works
- [ ] Long operations (100+ messages) work
- [ ] Operations with no chat messages show error
- [ ] Network error handling works

### Edge Cases
- [ ] Operation with 0 messages
- [ ] Operation with 1 message
- [ ] Operation with 1000+ messages
- [ ] Messages with only media (no text)
- [ ] Messages with special characters
- [ ] Messages with emojis
- [ ] Very long messages (1000+ characters)
- [ ] Media files that no longer exist in storage
- [ ] Multiple simultaneous exports (race conditions)

## Future Enhancements

### Potential Improvements
1. **Export Format Options**
   - CSV export
   - JSON export
   - HTML export

2. **Advanced Filtering**
   - Search by keyword
   - Filter by media type (photos only, videos only)
   - Filter by time of day

3. **Progress Bar**
   - Show percentage complete
   - Show current step (fetching, downloading, generating)
   - Cancel button

4. **Custom Templates**
   - Agency branding
   - Custom cover page
   - Include operation photos from targets

5. **Scheduled Exports**
   - Auto-export at operation end
   - Email to specified addresses

6. **Export History**
   - Track when exports were generated
   - Re-download previous exports

## Security Considerations

### Access Control
- ✅ Only members of the operation can export
- ✅ Must be authenticated
- ✅ RLS policies on `op_messages` table enforced

### Data Privacy
- ⚠️ Exported files stored in device temporary directory
- ⚠️ User responsible for secure handling after export
- ⚠️ No encryption on exported files (future enhancement)

### Recommendations
1. Add disclaimer in filter view about data sensitivity
2. Consider adding watermark with export timestamp and user ID
3. Optional encryption for sensitive operations

## Troubleshooting

### Common Issues

**"No messages to export"**
- Check if filters are too restrictive
- Verify operation actually has chat messages

**"Failed to download media"**
- Check network connection
- Verify media still exists in Supabase Storage
- Check Supabase Storage permissions

**"PDF generation failed"**
- Check device storage space
- Try with fewer messages (use date filter)

**Share sheet doesn't appear**
- Check view controller hierarchy
- Verify export completed successfully
- Check console logs for errors

## Code Maintenance

### Key Dependencies
- `PDFKit` (iOS native, no external deps)
- `UIKit` (for share sheet and PDF generation)
- `Supabase` (for database and storage access)

### Configuration
All hardcoded values are in `ChatExportService.swift`:
- Page size: 612 x 792 (US Letter)
- Margins: 50 points
- Thumbnail size: 100x100 points
- Font sizes: 24 (title), 14 (details), 12 (content), 11 (headers)

### Localization
Currently all strings are hardcoded in English. To add localization:
1. Extract all user-facing strings to `Localizable.strings`
2. Update filter view labels
3. Update PDF cover page text
4. Update error messages

