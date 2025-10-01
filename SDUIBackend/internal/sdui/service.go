package sdui

import (
	"context"
	"fmt"
	"path/filepath"
	"time"

	"github.com/google/uuid"

	"github.com/your-org/pestgenie-sdui/internal/models"
)

// Service encapsulates logic for selecting and personalising SDUI screens.
type Service struct {
	templateDir string
}

// NewService creates a service pointing at the on-disk template directory. When
// templateDir is empty the service falls back to programmatic defaults.
func NewService(templateDir string) *Service {
	return &Service{templateDir: templateDir}
}

// GetScreen resolves the requested screen and applies contextual data (user,
// route, device) before returning it to the caller.
func (s *Service) GetScreen(ctx context.Context, req models.ScreenRequest) (*models.SDUIScreen, error) {
	_ = ctx // reserved for future use (e.g., datastore lookups)

	screen := s.buildDefaultTechnicianScreen(req)

	// TODO: Attempt to load an override template from disk. This is left as an
	// exercise for future iterations once templates are authored externally.
	_ = filepath.Join(s.templateDir, fmt.Sprintf("%s.json", req.ScreenID))

	return &screen, nil
}

func (s *Service) buildDefaultTechnicianScreen(req models.ScreenRequest) models.SDUIScreen {
	serviceDate := req.ServiceDate
	if serviceDate.IsZero() {
		serviceDate = time.Now()
	}

	routeLabel := "No route assigned"
	if req.RouteID != "" {
		routeLabel = fmt.Sprintf("Route %s", req.RouteID)
	}

	header := models.SDUIComponent{
		ID:   uuid.NewString(),
		Type: "text",
		Text: "Good day, {{user.name}}",
		Font: "title2",
	}

	subheader := models.SDUIComponent{
		ID:    uuid.NewString(),
		Type:  "text",
		Text:  fmt.Sprintf("%s • %s", routeLabel, serviceDate.Format("Jan 2, 2006")),
		Font:  "subheadline",
		Color: "secondary",
	}

	metricsRow := models.SDUIComponent{
		ID:   uuid.NewString(),
		Type: "hstack",
		Children: []models.SDUIComponent{
			{
				ID:   uuid.NewString(),
				Type: "vstack",
				Children: []models.SDUIComponent{
					{Type: "text", Text: "Jobs today", Font: "caption", Color: "secondary"},
					{Type: "text", Text: "{{todayJobsCompleted}}", Font: "title3"},
				},
			},
			{
				ID:   uuid.NewString(),
				Type: "vstack",
				Children: []models.SDUIComponent{
					{Type: "text", Text: "Week total", Font: "caption", Color: "secondary"},
					{Type: "text", Text: "{{weekJobsCompleted}}", Font: "title3"},
				},
			},
			{
				ID:   uuid.NewString(),
				Type: "vstack",
				Children: []models.SDUIComponent{
					{Type: "text", Text: "Streak", Font: "caption", Color: "secondary"},
					{Type: "text", Text: "{{activeStreak}} days", Font: "title3"},
				},
			},
		},
	}

	jobList := models.SDUIComponent{
		ID:   uuid.NewString(),
		Type: "list",
		ItemView: &models.SDUIComponent{
			Type: "vstack",
			Children: []models.SDUIComponent{
				{
					Type: "hstack",
					Children: []models.SDUIComponent{
						{
							Type: "vstack",
							Children: []models.SDUIComponent{
								{Type: "text", Key: "customerName", Font: "headline"},
								{Type: "text", Key: "address", Font: "subheadline", Color: "secondary"},
								{Type: "text", Key: "scheduledTime", Font: "caption", Color: "secondary"},
							},
						},
						{Type: "spacer"},
						{Type: "text", Key: "status", Font: "caption", Color: "statusColor"},
					},
				},
				{
					Type:         "conditional",
					ConditionKey: "pinnedNotes",
					Children: []models.SDUIComponent{
						{Type: "text", Key: "pinnedNotes", Font: "caption", Color: "warning"},
					},
				},
				{
					Type: "hstack",
					Children: []models.SDUIComponent{
						{Type: "button", Label: "Start", ActionID: "startJob"},
						{Type: "button", Label: "Complete", ActionID: "completeJob"},
						{Type: "button", Label: "Skip", ActionID: "skipJob"},
					},
				},
			},
		},
	}

	communicationSection := models.SDUIComponent{
		ID:   uuid.NewString(),
		Type: "vstack",
		Children: []models.SDUIComponent{
			{Type: "text", Text: "Communications", Font: "headline"},
			{
				Type:         "conditional",
				ConditionKey: "route.hasCustomerAlerts",
				Children: []models.SDUIComponent{
					{Type: "text", Text: "{{route.alertSummary}}", Font: "body", Color: "warning"},
				},
			},
			{
				Type:         "conditional",
				ConditionKey: "route.hasComplianceTasks",
				Children: []models.SDUIComponent{
					{Type: "text", Text: "{{route.complianceHeadline}}", Font: "body", Color: "critical"},
				},
			},
		},
	}

	return models.SDUIScreen{
		Version: 5,
		Component: models.SDUIComponent{
			ID:   uuid.NewString(),
			Type: "scroll",
			Children: []models.SDUIComponent{
				{
					Type: "vstack",
					Children: []models.SDUIComponent{
						header,
						subheader,
						metricsRow,
						{
							Type: "divider",
						},
						jobList,
						{
							Type: "divider",
						},
						communicationSection,
						{
							Type:  "text",
							Text:  "Last sync {{lastSync}} • Profile {{profileCompleteness}} complete",
							Font:  "caption",
							Color: "secondary",
						},
					},
				},
			},
		},
	}
}
