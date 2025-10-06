package sdui

import (
	"context"
	"fmt"
	"path/filepath"
	"time"

	"log/slog"

	"github.com/google/uuid"

	domain "github.com/your-org/pestgenie-sdui/internal/domain/models"
	"github.com/your-org/pestgenie-sdui/internal/domain/repository"
	"github.com/your-org/pestgenie-sdui/internal/models"
)

// Service encapsulates logic for selecting and personalising SDUI screens.
type Service struct {
	templateDir string
	repos       repository.Repository
	logger      *slog.Logger
}

// NewService creates a service pointing at the on-disk template directory. When
// templateDir is empty the service falls back to programmatic defaults.
func NewService(templateDir string, repos repository.Repository, logger *slog.Logger) *Service {
	return &Service{templateDir: templateDir, repos: repos, logger: logger}
}

// GetScreen resolves the requested screen and applies contextual data (user,
// route, device) before returning it to the caller.
func (s *Service) GetScreen(ctx context.Context, req models.ScreenRequest) (*models.SDUIScreen, error) {
	tech, _ := s.repos.Technicians.GetByID(req.UserID)

	var route domain.Route
	if !req.ServiceDate.IsZero() {
		if r, err := s.repos.Routes.GetRoute(req.UserID, req.ServiceDate); err == nil {
			route = r
		}
	}

	screen := s.buildDefaultTechnicianScreen(req, tech, route)

	_ = filepath.Join(s.templateDir, fmt.Sprintf("%s.json", req.ScreenID))

	return &screen, nil
}

func (s *Service) buildDefaultTechnicianScreen(req models.ScreenRequest, tech domain.Technician, route domain.Route) models.SDUIScreen {
	serviceDate := req.ServiceDate
	if serviceDate.IsZero() {
		serviceDate = time.Now()
	}

	routeLabel := "No route assigned"
	if route.ID != "" {
		routeLabel = fmt.Sprintf("Route %s", route.ID)
	} else if req.RouteID != "" {
		routeLabel = fmt.Sprintf("Route %s", req.RouteID)
	}

	greeting := "Good day, Technician"
	if tech.DisplayName != "" {
		greeting = fmt.Sprintf("Good day, %s", tech.DisplayName)
	}

	header := models.SDUIComponent{
		ID:   uuid.NewString(),
		Type: "text",
		Text: greeting,
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

	if len(route.CustomerStops) > 0 {
		jobList.ItemView = nil
		jobList.Type = "vstack"
		jobList.Children = make([]models.SDUIComponent, 0, len(route.CustomerStops))
		for _, stop := range route.CustomerStops {
			jobList.Children = append(jobList.Children, models.SDUIComponent{
				ID:   uuid.NewString(),
				Type: "vstack",
				Children: []models.SDUIComponent{
					{
						Type: "text",
						Text: stop.CustomerName,
						Font: "headline",
					},
					{
						Type:  "text",
						Text:  stop.Address,
						Font:  "subheadline",
						Color: "secondary",
					},
					{
						Type:  "text",
						Text:  stop.WindowStart.Format("3:04 PM"),
						Font:  "caption",
						Color: "secondary",
					},
				},
			})
		}
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
